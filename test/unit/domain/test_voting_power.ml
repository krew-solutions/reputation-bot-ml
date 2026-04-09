module VP = Reputation_domain.Voting_power
module VPT = Reputation_domain.Voting_power_thresholds
module K = Reputation_domain.Karma

let tier = Alcotest.testable VP.pp_power_tier VP.equal_power_tier

let test_derive_newcomer () =
  let power = VPT.derive_power VPT.default ~effective_karma:(K.of_int 5) in
  Alcotest.(check tier) "karma 5 = Newcomer" VP.Newcomer (VP.tier power);
  Alcotest.(check (float 0.001)) "multiplier 0.5" 0.5 (VP.multiplier power)

let test_derive_regular () =
  let power = VPT.derive_power VPT.default ~effective_karma:(K.of_int 10) in
  Alcotest.(check tier) "karma 10 = Regular" VP.Regular (VP.tier power)

let test_derive_trusted () =
  let power = VPT.derive_power VPT.default ~effective_karma:(K.of_int 100) in
  Alcotest.(check tier) "karma 100 = Trusted" VP.Trusted (VP.tier power);
  Alcotest.(check (float 0.001)) "multiplier 1.5" 1.5 (VP.multiplier power)

let test_derive_elder () =
  let power = VPT.derive_power VPT.default ~effective_karma:(K.of_int 500) in
  Alcotest.(check tier) "karma 500 = Elder" VP.Elder (VP.tier power);
  Alcotest.(check (float 0.001)) "multiplier 2.0" 2.0 (VP.multiplier power)

let test_thresholds_invalid () =
  let result = VPT.create ~regular:(K.of_int 100) ~trusted:(K.of_int 50)
      ~elder:(K.of_int 500) in
  Alcotest.(check (option (Alcotest.testable VPT.pp VPT.equal)))
    "regular > trusted" None result

let test_zero_karma () =
  let power = VPT.derive_power VPT.default ~effective_karma:(K.of_int 0) in
  Alcotest.(check tier) "karma 0 = Newcomer" VP.Newcomer (VP.tier power)

let () =
  Alcotest.run "Voting_power"
    [
      ( "derive",
        [
          Alcotest.test_case "newcomer" `Quick test_derive_newcomer;
          Alcotest.test_case "regular" `Quick test_derive_regular;
          Alcotest.test_case "trusted" `Quick test_derive_trusted;
          Alcotest.test_case "elder" `Quick test_derive_elder;
          Alcotest.test_case "zero karma" `Quick test_zero_karma;
        ] );
      ( "thresholds",
        [
          Alcotest.test_case "invalid" `Quick test_thresholds_invalid;
        ] );
    ]
