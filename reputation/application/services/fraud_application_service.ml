(** Fraud application service — orchestrates fraud detection and correction. *)

open Reputation_domain
open Ascetic_ddd.Result_ext

let recalculate_fraud_scores (type uow) (deps : uow Deps.t) (uow : uow)
    ~(member_ids : Ids.Member_id.t list) ~(community_id : Ids.Community_id.t) =
  traverse
    (fun member_id ->
      Update_fraud_score.handle deps uow { member_id; community_id })
    member_ids
  |> Result.map (fun _ -> ())

let detect_and_correct_rings (type uow) (deps : uow Deps.t) (uow : uow)
    ~(community_id : Ids.Community_id.t) =
  let (module FraudDetection) = deps.fraud_detection in
  let (module EventPub) = deps.event_publisher in
  let (module Clock) = deps.clock in
  let now = Clock.now () in
  let* rings =
    FraudDetection.detect_voting_rings uow community_id
    |> map_error (fun e -> Domain_error.Invalid_argument e)
  in
  traverse
    (fun ring_member_ids ->
      (* Estimate total fraudulent karma — simplified *)
      let total_karma =
        Karma.of_int (List.length ring_member_ids * 10)
      in
      (* Publish detection event *)
      let event : Domain_events.t =
        VotingRingDetected
          { ring_member_ids; total_fraudulent_karma = total_karma }
      in
      let envelope =
        Ascetic_ddd.Domain_event.create ~aggregate_id:"fraud-detection"
          ~aggregate_version:0 ~occurred_at:now event
      in
      let* () =
        EventPub.publish uow [ envelope ]
        |> map_error (fun e -> Domain_error.Invalid_argument e)
      in
      (* Apply corrections *)
      Apply_ring_correction.handle deps uow
        { ring_member_ids; total_fraudulent_karma = total_karma })
    rings
  |> Result.map (fun _ -> ())
