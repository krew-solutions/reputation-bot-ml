module SWB = Reputation_domain.Sliding_window_budget
module BWS = Reputation_domain.Budget_window_set
module DE = Reputation_domain.Domain_error

let now = Ptime.of_float_s 1_700_000_000.0 |> Option.get  (* ~2023-11-14 *)
let hour_later =
  Ptime.add_span now (Ptime.Span.of_int_s 3600) |> Option.get

let test_empty_budget_ok () =
  let b = SWB.empty in
  let result = SWB.check b ~now ~budget:BWS.default in
  Alcotest.(check bool) "empty budget OK" true (Result.is_ok result)

let test_record_and_count () =
  let b = SWB.empty in
  let b = SWB.record_action b ~now in
  let b = SWB.record_action b ~now in
  let hourly = List.hd (BWS.windows BWS.default) in
  let count = SWB.action_count_in_window b ~now hourly in
  Alcotest.(check int) "2 actions" 2 count

let test_hourly_budget_exhaustion () =
  let budget = BWS.default in
  let b = ref SWB.empty in
  for _ = 1 to 5 do
    b := SWB.record_action !b ~now
  done;
  let result = SWB.check !b ~now ~budget in
  match result with
  | Error (DE.Budget_exhausted { window_name }) ->
      Alcotest.(check string) "hourly exhausted" "hourly" window_name
  | _ -> Alcotest.fail "should be Budget_exhausted"

let test_actions_outside_window_not_counted () =
  let old_time =
    Ptime.sub_span now (Ptime.Span.of_int_s (2 * 3600)) |> Option.get
  in
  let b = SWB.empty in
  (* Record 5 actions 2 hours ago *)
  let b = ref b in
  for _ = 1 to 5 do
    b := SWB.record_action !b ~now:old_time
  done;
  (* Now they should be outside the hourly window *)
  let result = SWB.check !b ~now ~budget:BWS.default in
  Alcotest.(check bool) "old actions OK" true (Result.is_ok result)

let test_prune () =
  let old_time =
    Ptime.sub_span now (Ptime.Span.of_int_s (8 * 24 * 3600)) |> Option.get
  in
  let b = SWB.empty in
  let b = SWB.record_action b ~now:old_time in
  let b = SWB.record_action b ~now in
  let pruned = SWB.prune b ~now ~budget:BWS.default in
  let ts = SWB.export_timestamps pruned in
  Alcotest.(check int) "pruned to 1" 1 (List.length ts)

let test_export_import_roundtrip () =
  let b = SWB.empty in
  let b = SWB.record_action b ~now in
  let b = SWB.record_action b ~now:hour_later in
  let ts = SWB.export_timestamps b in
  let b2 = SWB.import_timestamps ts in
  Alcotest.(check bool) "roundtrip" true (SWB.equal b b2)

let () =
  Alcotest.run "Sliding_window_budget"
    [
      ( "check",
        [
          Alcotest.test_case "empty OK" `Quick test_empty_budget_ok;
          Alcotest.test_case "record and count" `Quick test_record_and_count;
          Alcotest.test_case "hourly exhaustion" `Quick
            test_hourly_budget_exhaustion;
          Alcotest.test_case "outside window" `Quick
            test_actions_outside_window_not_counted;
        ] );
      ( "maintenance",
        [
          Alcotest.test_case "prune" `Quick test_prune;
          Alcotest.test_case "export/import" `Quick test_export_import_roundtrip;
        ] );
    ]
