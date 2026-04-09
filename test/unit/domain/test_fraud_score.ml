module FS = Reputation_domain.Fraud_score
module FF = Reputation_domain.Fraud_factors
module TF = Reputation_domain.Taint_factor

let classification =
  Alcotest.testable FS.pp_classification FS.equal_classification

let test_classify_clean () =
  let s = FS.of_int_exn 0 in
  Alcotest.(check classification) "0 = Clean" FS.Clean (FS.classify s)

let test_classify_suspicious () =
  let s = FS.of_int_exn 25 in
  Alcotest.(check classification) "25 = Suspicious" FS.Suspicious (FS.classify s)

let test_classify_likely () =
  let s = FS.of_int_exn 60 in
  Alcotest.(check classification) "60 = LikelyFraud" FS.LikelyFraud (FS.classify s)

let test_classify_confirmed () =
  let s = FS.of_int_exn 80 in
  Alcotest.(check classification) "80 = ConfirmedFraud" FS.ConfirmedFraud
    (FS.classify s)

let test_boundaries () =
  Alcotest.(check classification) "19 = Clean" FS.Clean
    (FS.classify (FS.of_int_exn 19));
  Alcotest.(check classification) "20 = Suspicious" FS.Suspicious
    (FS.classify (FS.of_int_exn 20));
  Alcotest.(check classification) "49 = Suspicious" FS.Suspicious
    (FS.classify (FS.of_int_exn 49));
  Alcotest.(check classification) "50 = LikelyFraud" FS.LikelyFraud
    (FS.classify (FS.of_int_exn 50));
  Alcotest.(check classification) "79 = LikelyFraud" FS.LikelyFraud
    (FS.classify (FS.of_int_exn 79))

let test_out_of_range () =
  Alcotest.(check (option (Alcotest.testable FS.pp FS.equal)))
    "out of range" None (FS.of_int 101);
  Alcotest.(check (option (Alcotest.testable FS.pp FS.equal)))
    "negative" None (FS.of_int (-1))

let test_fraud_factors_to_score () =
  let factors =
    FF.create ~reciprocal_voting:10 ~vote_concentration:15
      ~ring_participation:20 ~karma_ratio_anomaly:5 ~velocity_anomaly:0
  in
  let score = FF.to_fraud_score factors in
  Alcotest.(check int) "sum = 50" 50 (FS.to_int score)

let test_fraud_factors_capped () =
  let factors =
    FF.create ~reciprocal_voting:50 ~vote_concentration:30
      ~ring_participation:40 ~karma_ratio_anomaly:25 ~velocity_anomaly:10
  in
  let score = FF.to_fraud_score factors in
  Alcotest.(check int) "capped at 100" 100 (FS.to_int score)

let test_taint_factor_clean () =
  let tf = TF.of_fraud_score (FS.of_int_exn 10) in
  Alcotest.(check (float 0.001)) "clean = 1.0" 1.0 (TF.to_float tf)

let test_taint_factor_suspicious () =
  let tf = TF.of_fraud_score (FS.of_int_exn 30) in
  Alcotest.(check (float 0.001)) "suspicious = 0.7" 0.7 (TF.to_float tf)

let test_taint_factor_likely () =
  let tf = TF.of_fraud_score (FS.of_int_exn 60) in
  Alcotest.(check (float 0.001)) "likely = 0.3" 0.3 (TF.to_float tf)

let test_taint_factor_confirmed () =
  let tf = TF.of_fraud_score (FS.of_int_exn 90) in
  Alcotest.(check (float 0.001)) "confirmed = 0.0" 0.0 (TF.to_float tf);
  Alcotest.(check bool) "is_blocked" true (TF.is_blocked tf)

let () =
  Alcotest.run "Fraud"
    [
      ( "classification",
        [
          Alcotest.test_case "clean" `Quick test_classify_clean;
          Alcotest.test_case "suspicious" `Quick test_classify_suspicious;
          Alcotest.test_case "likely" `Quick test_classify_likely;
          Alcotest.test_case "confirmed" `Quick test_classify_confirmed;
          Alcotest.test_case "boundaries" `Quick test_boundaries;
          Alcotest.test_case "out of range" `Quick test_out_of_range;
        ] );
      ( "factors",
        [
          Alcotest.test_case "to score" `Quick test_fraud_factors_to_score;
          Alcotest.test_case "capped at 100" `Quick test_fraud_factors_capped;
        ] );
      ( "taint",
        [
          Alcotest.test_case "clean" `Quick test_taint_factor_clean;
          Alcotest.test_case "suspicious" `Quick test_taint_factor_suspicious;
          Alcotest.test_case "likely" `Quick test_taint_factor_likely;
          Alcotest.test_case "confirmed" `Quick test_taint_factor_confirmed;
        ] );
    ]
