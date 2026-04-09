module M = Reputation_domain.Member
module K = Reputation_domain.Karma
module DK = Reputation_domain.Dual_karma
module FF = Reputation_domain.Fraud_factors
module VP = Reputation_domain.Voting_power
module VPT = Reputation_domain.Voting_power_thresholds
module BWS = Reputation_domain.Budget_window_set
module Ids = Reputation_domain.Ids

let mid = Ids.Member_id.of_int 1
let cid = Ids.Community_id.of_int 1
let source_mid = Ids.Member_id.of_int 2
let now = Ptime.of_float_s 1_700_000_000.0 |> Option.get

let make_member () = M.register ~id:mid ~community_id:cid ~now

let test_register () =
  let m = make_member () in
  Alcotest.(check bool) "id" true (Ids.Member_id.equal mid (M.id m));
  Alcotest.(check int) "version 1" 1 (M.version m);
  Alcotest.(check (float 0.001)) "karma zero" 0.0
    (K.to_float (DK.public (M.dual_karma m)));
  Alcotest.(check int) "1 uncommitted event" 1
    (List.length (M.uncommitted_events m))

let test_receive_karma () =
  let m = make_member () in
  let m =
    M.receive_karma m ~delta:(K.of_int 10) ~taint_factor:1.0
      ~source_member_id:source_mid ~reason:"vote" ~now
  in
  Alcotest.(check (float 0.001)) "public 10" 10.0
    (K.to_float (DK.public (M.dual_karma m)));
  Alcotest.(check (float 0.001)) "effective 10" 10.0
    (K.to_float (DK.effective (M.dual_karma m)));
  Alcotest.(check int) "version 2" 2 (M.version m)

let test_receive_karma_tainted () =
  let m = make_member () in
  let m =
    M.receive_karma m ~delta:(K.of_int 10) ~taint_factor:0.3
      ~source_member_id:source_mid ~reason:"tainted vote" ~now
  in
  Alcotest.(check (float 0.001)) "public 10" 10.0
    (K.to_float (DK.public (M.dual_karma m)));
  Alcotest.(check (float 0.1)) "effective ~3" 3.0
    (K.to_float (DK.effective (M.dual_karma m)))

let test_record_vote () =
  let m = make_member () in
  let m = M.record_vote m ~now in
  Alcotest.(check int) "version 2" 2 (M.version m);
  let ts = Reputation_domain.Sliding_window_budget.export_timestamps (M.budget m) in
  Alcotest.(check int) "1 timestamp" 1 (List.length ts)

let test_can_vote_clean () =
  let m = make_member () in
  let result = M.can_vote m ~now ~budget_windows:BWS.default in
  Alcotest.(check bool) "clean can vote" true (Result.is_ok result)

let test_can_vote_fraud_blocked () =
  let m = make_member () in
  let factors =
    FF.create ~reciprocal_voting:40 ~vote_concentration:30
      ~ring_participation:20 ~karma_ratio_anomaly:0 ~velocity_anomaly:0
  in
  let m = M.update_fraud_score m ~factors ~now in
  (* Score = 90, ConfirmedFraud *)
  let result = M.can_vote m ~now ~budget_windows:BWS.default in
  Alcotest.(check bool) "fraud blocked" true (Result.is_error result)

let test_effective_voting_power () =
  let m = make_member () in
  let m =
    M.receive_karma m ~delta:(K.of_int 150) ~taint_factor:1.0
      ~source_member_id:source_mid ~reason:"lots of karma" ~now
  in
  let power = M.effective_voting_power m ~thresholds:VPT.default in
  Alcotest.(check (Alcotest.testable VP.pp_power_tier VP.equal_power_tier))
    "trusted tier" VP.Trusted (VP.tier power)

let test_fraud_penalty_on_voting_power () =
  let m = make_member () in
  let m =
    M.receive_karma m ~delta:(K.of_int 150) ~taint_factor:1.0
      ~source_member_id:source_mid ~reason:"karma" ~now
  in
  (* Make suspicious *)
  let factors =
    FF.create ~reciprocal_voting:15 ~vote_concentration:10
      ~ring_participation:0 ~karma_ratio_anomaly:0 ~velocity_anomaly:0
  in
  let m = M.update_fraud_score m ~factors ~now in
  let power = M.effective_voting_power m ~thresholds:VPT.default in
  (* Suspicious: penalty = 0.7, base for Trusted = 1.5, result = 1.05 *)
  Alcotest.(check (float 0.001)) "penalized multiplier" 1.05
    (VP.multiplier power)

let test_apply_correction () =
  let m = make_member () in
  let m =
    M.receive_karma m ~delta:(K.of_int 20) ~taint_factor:1.0
      ~source_member_id:source_mid ~reason:"votes" ~now
  in
  let m =
    M.apply_correction m ~effective_delta:(K.of_int (-10))
      ~reason:"ring correction" ~now
  in
  Alcotest.(check (float 0.001)) "public unchanged" 20.0
    (K.to_float (DK.public (M.dual_karma m)));
  Alcotest.(check (float 0.001)) "effective 10" 10.0
    (K.to_float (DK.effective (M.dual_karma m)))

let test_event_sourcing_reconstitution () =
  let m = make_member () in
  let m =
    M.receive_karma m ~delta:(K.of_int 50) ~taint_factor:1.0
      ~source_member_id:source_mid ~reason:"vote" ~now
  in
  let m = M.record_vote m ~now in
  (* Collect events *)
  let events = M.uncommitted_events m in
  (* Reconstitute from scratch *)
  let m2 = M.initial_state ~id:mid ~community_id:cid in
  let m2 =
    List.fold_left
      (fun state envelope -> M.apply_event state envelope.Ascetic_ddd.Domain_event.payload)
      m2 events
  in
  (* Should have same state (minus uncommitted_events) *)
  Alcotest.(check (float 0.001)) "reconstituted public" 50.0
    (K.to_float (DK.public (M.dual_karma m2)));
  Alcotest.(check int) "reconstituted budget"
    (List.length
       (Reputation_domain.Sliding_window_budget.export_timestamps (M.budget m)))
    (List.length
       (Reputation_domain.Sliding_window_budget.export_timestamps (M.budget m2)))

let () =
  Alcotest.run "Member"
    [
      ( "construction",
        [
          Alcotest.test_case "register" `Quick test_register;
        ] );
      ( "karma",
        [
          Alcotest.test_case "receive clean" `Quick test_receive_karma;
          Alcotest.test_case "receive tainted" `Quick test_receive_karma_tainted;
          Alcotest.test_case "correction" `Quick test_apply_correction;
        ] );
      ( "voting",
        [
          Alcotest.test_case "record vote" `Quick test_record_vote;
          Alcotest.test_case "can vote clean" `Quick test_can_vote_clean;
          Alcotest.test_case "fraud blocked" `Quick test_can_vote_fraud_blocked;
        ] );
      ( "voting power",
        [
          Alcotest.test_case "effective power" `Quick test_effective_voting_power;
          Alcotest.test_case "fraud penalty" `Quick
            test_fraud_penalty_on_voting_power;
        ] );
      ( "event sourcing",
        [
          Alcotest.test_case "reconstitution" `Quick
            test_event_sourcing_reconstitution;
        ] );
    ]
