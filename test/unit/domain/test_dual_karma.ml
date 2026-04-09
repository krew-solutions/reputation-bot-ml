module DK = Reputation_domain.Dual_karma
module K = Reputation_domain.Karma
module D = Ascetic_ddd.Decimal

let dk = Alcotest.testable DK.pp DK.equal

let test_initial () =
  let t = DK.initial in
  Alcotest.(check (float 0.001)) "public zero" 0.0 (K.to_float (DK.public t));
  Alcotest.(check (float 0.001)) "effective zero" 0.0 (K.to_float (DK.effective t))

let test_create_valid () =
  let pub = K.of_int 10 in
  let eff = K.of_int 5 in
  match DK.create ~public:pub ~effective:eff with
  | Some t ->
      Alcotest.(check (float 0.001)) "public" 10.0 (K.to_float (DK.public t));
      Alcotest.(check (float 0.001)) "effective" 5.0 (K.to_float (DK.effective t))
  | None -> Alcotest.fail "should succeed when effective <= public"

let test_create_invalid () =
  let pub = K.of_int 5 in
  let eff = K.of_int 10 in
  Alcotest.(check (option dk)) "effective > public" None
    (DK.create ~public:pub ~effective:eff)

let test_receive_clean () =
  let t = DK.initial in
  let t = DK.receive t ~delta:(K.of_int 10) ~taint_factor:1.0 in
  Alcotest.(check (float 0.001)) "public 10" 10.0 (K.to_float (DK.public t));
  Alcotest.(check (float 0.001)) "effective 10" 10.0 (K.to_float (DK.effective t))

let test_receive_suspicious () =
  let t = DK.initial in
  let t = DK.receive t ~delta:(K.of_int 10) ~taint_factor:0.7 in
  Alcotest.(check (float 0.001)) "public 10" 10.0 (K.to_float (DK.public t));
  Alcotest.(check (float 0.001)) "effective 7" 7.0 (K.to_float (DK.effective t))

let test_receive_confirmed_fraud () =
  let t = DK.initial in
  let t = DK.receive t ~delta:(K.of_int 10) ~taint_factor:0.0 in
  Alcotest.(check (float 0.001)) "public 10" 10.0 (K.to_float (DK.public t));
  Alcotest.(check (float 0.001)) "effective 0" 0.0 (K.to_float (DK.effective t))

let test_invariant_effective_le_public () =
  let t = DK.initial in
  (* Receive with full taint *)
  let t = DK.receive t ~delta:(K.of_int 10) ~taint_factor:1.0 in
  Alcotest.(check bool) "eff <= pub"
    true (D.compare (DK.effective t |> K.to_decimal) (DK.public t |> K.to_decimal) <= 0)

let test_apply_correction_reduces_effective () =
  let t = DK.initial in
  let t = DK.receive t ~delta:(K.of_int 20) ~taint_factor:1.0 in
  let t = DK.apply_correction t ~effective_delta:(K.of_int (-5)) in
  Alcotest.(check (float 0.001)) "public unchanged" 20.0 (K.to_float (DK.public t));
  Alcotest.(check (float 0.001)) "effective 15" 15.0 (K.to_float (DK.effective t))

let test_apply_correction_clamps_to_zero () =
  let t = DK.initial in
  let t = DK.receive t ~delta:(K.of_int 5) ~taint_factor:1.0 in
  let t = DK.apply_correction t ~effective_delta:(K.of_int (-100)) in
  Alcotest.(check (float 0.001)) "effective clamped to 0" 0.0
    (K.to_float (DK.effective t))

let () =
  Alcotest.run "Dual_karma"
    [
      ( "construction",
        [
          Alcotest.test_case "initial" `Quick test_initial;
          Alcotest.test_case "create valid" `Quick test_create_valid;
          Alcotest.test_case "create invalid" `Quick test_create_invalid;
        ] );
      ( "receive",
        [
          Alcotest.test_case "clean" `Quick test_receive_clean;
          Alcotest.test_case "suspicious" `Quick test_receive_suspicious;
          Alcotest.test_case "confirmed fraud" `Quick test_receive_confirmed_fraud;
          Alcotest.test_case "invariant" `Quick test_invariant_effective_le_public;
        ] );
      ( "correction",
        [
          Alcotest.test_case "reduces effective" `Quick
            test_apply_correction_reduces_effective;
          Alcotest.test_case "clamps to zero" `Quick
            test_apply_correction_clamps_to_zero;
        ] );
    ]
