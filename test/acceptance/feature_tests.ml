(** Feature file runner — connects .feature files to step definitions.

    Uses the Ascetic Gherkin parser + runner with the existing
    test harness for in-memory infrastructure. *)

open Reputation_domain

module Runner = Ascetic_gherkin.Runner

type ctx = Test_harness.ctx

let steps : ctx Runner.t = Runner.create ()

(* === Step Definitions === *)

let () =
  (* Given steps *)
  Runner.given steps {|a community "([^"]+)" with a chat|} (fun ctx args ->
      let name = List.hd args in
      ctx
      |> Test_harness.create_community ~name
      |> Test_harness.attach_chat);

  Runner.given steps {|a member "([^"]+)"|} (fun ctx args ->
      let name = List.hd args in
      Test_harness.register_member ctx ~name);

  Runner.given steps {|"([^"]+)" posted message "([^"]+)"|} (fun ctx args ->
      let author_name = List.nth args 0 in
      let label = List.nth args 1 in
      Test_harness.post_message ctx ~author_name ~label);

  Runner.given steps {|"([^"]+)" upvotes message "([^"]+)"|} (fun ctx args ->
      let voter_name = List.nth args 0 in
      let message_label = List.nth args 1 in
      Test_harness.cast_vote ctx ~voter_name ~message_label
        ~vote_type:Vote_type.Up);

  Runner.given steps {|"([^"]+)" has fraud score ([0-9]+)|} (fun ctx args ->
      let name = List.nth args 0 in
      let score = int_of_string (List.nth args 1) in
      let member_id = List.assoc name ctx.members in
      let factors =
        Fraud_factors.create ~reciprocal_voting:(score / 3)
          ~vote_concentration:(score / 3)
          ~ring_participation:(score - score / 3 - score / 3)
          ~karma_ratio_anomaly:0 ~velocity_anomaly:0
      in
      let (module ES) = ctx.deps.event_store in
      let now = Ptime.of_float_s 1_700_000_000.0 |> Option.get in
      let event = Member.FraudScoreChanged {
        old_score = Fraud_score.zero;
        new_score = Fraud_score.of_int_clamped score;
        factors;
      } in
      let envelope =
        Ascetic_ddd.Domain_event.create
          ~aggregate_id:(Ids.Member_id.show member_id)
          ~aggregate_version:2 ~occurred_at:now event
      in
      ignore (ES.append ()
                ~aggregate_id:(Ids.Member_id.show member_id)
                ~expected_version:1 [envelope]);
      ctx);

  (* When steps *)
  Runner.when_ steps {|"([^"]+)" upvotes message "([^"]+)"|} (fun ctx args ->
      let voter_name = List.nth args 0 in
      let message_label = List.nth args 1 in
      Test_harness.cast_vote ctx ~voter_name ~message_label
        ~vote_type:Vote_type.Up);

  Runner.when_ steps {|"([^"]+)" downvotes message "([^"]+)"|} (fun ctx args ->
      let voter_name = List.nth args 0 in
      let message_label = List.nth args 1 in
      Test_harness.cast_vote ctx ~voter_name ~message_label
        ~vote_type:Vote_type.Down);

  (* Then steps *)
  Runner.then_ steps {|"([^"]+)" has positive karma|} (fun ctx args ->
      let name = List.hd args in
      let pub, _eff = Test_harness.get_member_karma ctx ~name in
      Alcotest.(check bool) "karma > 0" true (pub > 0.0);
      ctx);

  Runner.then_ steps {|last karma delta is negative|} (fun ctx _args ->
      (match ctx.last_karma_delta with
       | Some d ->
           Alcotest.(check bool) "delta < 0" true (Karma.is_negative d)
       | None -> Alcotest.fail "expected karma delta");
      ctx);

  Runner.then_ steps {|the error is "([^"]+)"|} (fun ctx args ->
      let expected = List.hd args in
      (match ctx.last_error with
       | Some err ->
           let err_str = Domain_error.show err in
           Alcotest.(check bool)
             (Printf.sprintf "error contains %s" expected)
             true (String.length err_str > 0 &&
                   let re = Re.Perl.compile_pat expected in
                   Re.execp re err_str)
       | None -> Alcotest.fail "expected an error");
      ctx)

(* === Run .feature files via Alcotest === *)

let feature_dir =
  (* Find features relative to the test binary *)
  let candidates = [
    "test/features";
    "../test/features";
    "../../test/features";
  ] in
  List.find Sys.file_exists candidates

let load_feature name =
  Runner.to_alcotest_from_file steps
    ~make_ctx:Test_harness.fresh_ctx
    (Filename.concat feature_dir name)

let () =
  Alcotest.run "Feature Tests"
    [
      load_feature "vote_casting.feature";
      load_feature "budget.feature";
      load_feature "fraud.feature";
    ]
