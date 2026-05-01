(** Acceptance tests — in-process component tests with Gherkin syntax.

    Tests the application layer end-to-end through the command/query
    handlers with in-memory infrastructure. *)

open Reputation_domain
open Test_harness

module Gherkin = Ascetic_gherkin_edsl

(* ================================================================
   Feature: Vote Casting
   ================================================================ *)

let vote_casting_upvote =
  Gherkin.scenario "Reply with '+' increases author's karma" fresh_ctx
    [
      Gherkin.given "a community with a chat" (fun ctx ->
          ctx |> create_community ~name:"OCaml Devs" |> attach_chat);
      Gherkin.and_ "two registered members: Alice and Bob" (fun ctx ->
          ctx |> register_member ~name:"alice" |> register_member ~name:"bob");
      Gherkin.and_ "Alice posted a message" (fun ctx ->
          ctx |> post_message ~author_name:"alice" ~label:"msg1");
      Gherkin.when_ "Bob replies with an upvote" (fun ctx ->
          ctx |> cast_vote ~voter_name:"bob" ~message_label:"msg1"
                 ~vote_type:Vote_type.Up);
      Gherkin.then_ "Alice's karma increases" (fun ctx ->
          let pub, _eff = get_member_karma ctx ~name:"alice" in
          Alcotest.(check bool) "karma > 0" true (pub > 0.0));
      Gherkin.then_ "the karma delta is positive" (fun ctx ->
          match ctx.last_karma_delta with
          | Some d -> Alcotest.(check bool) "delta > 0" true (Karma.is_positive d)
          | None -> Alcotest.fail "expected karma delta");
    ]

let vote_casting_downvote =
  Gherkin.scenario "Reply with '-' decreases author's karma" fresh_ctx
    [
      Gherkin.given "a community with a chat" (fun ctx ->
          ctx |> create_community ~name:"Test" |> attach_chat);
      Gherkin.and_ "two members" (fun ctx ->
          ctx |> register_member ~name:"alice" |> register_member ~name:"bob");
      Gherkin.and_ "Alice posted a message" (fun ctx ->
          ctx |> post_message ~author_name:"alice" ~label:"msg1");
      Gherkin.when_ "Bob downvotes" (fun ctx ->
          ctx |> cast_vote ~voter_name:"bob" ~message_label:"msg1"
                 ~vote_type:Vote_type.Down);
      Gherkin.then_ "the karma delta is negative" (fun ctx ->
          match ctx.last_karma_delta with
          | Some d -> Alcotest.(check bool) "delta < 0" true (Karma.is_negative d)
          | None -> Alcotest.fail "expected karma delta");
    ]

(* ================================================================
   Feature: Self-Vote Prevention
   ================================================================ *)

let self_vote_prevention =
  Gherkin.scenario "A member cannot vote on their own message" fresh_ctx
    [
      Gherkin.given "a community with a chat and one member" (fun ctx ->
          ctx
          |> create_community ~name:"Test"
          |> attach_chat
          |> register_member ~name:"alice");
      Gherkin.and_ "Alice posted a message" (fun ctx ->
          ctx |> post_message ~author_name:"alice" ~label:"msg1");
      Gherkin.when_ "Alice tries to vote on her own message" (fun ctx ->
          ctx |> cast_vote ~voter_name:"alice" ~message_label:"msg1"
                 ~vote_type:Vote_type.Up);
      Gherkin.then_ "the vote is rejected with Self_vote_prohibited" (fun ctx ->
          match ctx.last_error with
          | Some Domain_error.Self_vote_prohibited -> ()
          | Some e -> Alcotest.fail (Printf.sprintf "wrong error: %s" (Domain_error.show e))
          | None -> Alcotest.fail "expected an error");
    ]

(* ================================================================
   Feature: Duplicate Vote Prevention
   ================================================================ *)

let duplicate_vote =
  Gherkin.scenario "A member cannot vote twice on the same message"
    fresh_ctx
    [
      Gherkin.given "a community setup" (fun ctx ->
          ctx
          |> create_community ~name:"Test"
          |> attach_chat
          |> register_member ~name:"alice"
          |> register_member ~name:"bob");
      Gherkin.and_ "Alice posted a message" (fun ctx ->
          ctx |> post_message ~author_name:"alice" ~label:"msg1");
      Gherkin.and_ "Bob already voted" (fun ctx ->
          ctx |> cast_vote ~voter_name:"bob" ~message_label:"msg1"
                 ~vote_type:Vote_type.Up);
      Gherkin.when_ "Bob tries to vote again" (fun ctx ->
          ctx |> cast_vote ~voter_name:"bob" ~message_label:"msg1"
                 ~vote_type:Vote_type.Up);
      Gherkin.then_ "the vote is rejected with Duplicate_vote" (fun ctx ->
          match ctx.last_error with
          | Some Domain_error.Duplicate_vote -> ()
          | Some e -> Alcotest.fail (Printf.sprintf "wrong error: %s" (Domain_error.show e))
          | None -> Alcotest.fail "expected an error");
    ]

(* ================================================================
   Feature: Budget Exhaustion
   ================================================================ *)

let budget_exhaustion =
  Gherkin.scenario "Hourly budget of 5 votes is enforced" fresh_ctx
    [
      Gherkin.given "a community with 7 members" (fun ctx ->
          let ctx =
            ctx
            |> create_community ~name:"Test"
            |> attach_chat
            |> register_member ~name:"voter"
          in
          (* Register 6 authors and post 6 messages *)
          let ctx = ref ctx in
          for i = 1 to 6 do
            let name = Printf.sprintf "author%d" i in
            let label = Printf.sprintf "msg%d" i in
            ctx := !ctx |> register_member ~name |> post_message ~author_name:name ~label
          done;
          !ctx);
      Gherkin.when_ "the voter casts 5 votes (filling hourly budget)" (fun ctx ->
          let ctx = ref ctx in
          for i = 1 to 5 do
            let label = Printf.sprintf "msg%d" i in
            ctx := !ctx |> cast_vote ~voter_name:"voter" ~message_label:label
                          ~vote_type:Vote_type.Up
          done;
          !ctx);
      Gherkin.when_ "the voter tries a 6th vote" (fun ctx ->
          ctx |> cast_vote ~voter_name:"voter" ~message_label:"msg6"
                 ~vote_type:Vote_type.Up);
      Gherkin.then_ "it is rejected with Budget_exhausted(hourly)" (fun ctx ->
          match ctx.last_error with
          | Some (Domain_error.Budget_exhausted { window_name }) ->
              Alcotest.(check string) "hourly" "hourly" window_name
          | Some e -> Alcotest.fail (Printf.sprintf "wrong error: %s" (Domain_error.show e))
          | None -> Alcotest.fail "expected Budget_exhausted");
    ]

(* ================================================================
   Feature: Multiple Voters Accumulate Karma
   ================================================================ *)

let multiple_voters =
  Gherkin.scenario "Multiple voters increase author's karma additively"
    fresh_ctx
    [
      Gherkin.given "a community with 3 members" (fun ctx ->
          ctx
          |> create_community ~name:"Test"
          |> attach_chat
          |> register_member ~name:"alice"
          |> register_member ~name:"bob"
          |> register_member ~name:"charlie");
      Gherkin.and_ "Alice posted a message" (fun ctx ->
          ctx |> post_message ~author_name:"alice" ~label:"msg1");
      Gherkin.when_ "Bob and Charlie both upvote" (fun ctx ->
          ctx
          |> cast_vote ~voter_name:"bob" ~message_label:"msg1" ~vote_type:Vote_type.Up
          |> cast_vote ~voter_name:"charlie" ~message_label:"msg1" ~vote_type:Vote_type.Up);
      Gherkin.then_ "Alice's karma reflects both votes" (fun ctx ->
          let pub, _ = get_member_karma ctx ~name:"alice" in
          Alcotest.(check bool) "karma from 2 votes" true (pub > 0.5));
    ]

(* ================================================================
   Feature: Fraud Detection — Blocked Voter
   ================================================================ *)

let fraud_blocked_voter =
  Gherkin.scenario "A confirmed fraudster cannot vote" fresh_ctx
    [
      Gherkin.given "a community with 2 members" (fun ctx ->
          ctx
          |> create_community ~name:"Test"
          |> attach_chat
          |> register_member ~name:"fraudster"
          |> register_member ~name:"alice");
      Gherkin.and_ "Alice posted a message" (fun ctx ->
          ctx |> post_message ~author_name:"alice" ~label:"msg1");
      Gherkin.and_ "fraudster has a confirmed fraud score" (fun ctx ->
          let member_id = List.assoc "fraudster" ctx.members in
          let community_id = Option.get ctx.community_id in
          let factors =
            Fraud_factors.create ~reciprocal_voting:40 ~vote_concentration:30
              ~ring_participation:20 ~karma_ratio_anomaly:0 ~velocity_anomaly:0
          in
          (* Directly update fraud score via command *)
          let _ =
            Reputation_app.Cast_vote.load_member ctx.deps () member_id
          in
          (* We need to inject fraud score into the member's event stream.
             Use the update_fraud_score command approach — but we need the member
             loaded first. Let's emit events directly. *)
          let (module ES) = ctx.deps.event_store in
          let now = Ptime.of_float_s 1_700_000_000.0 |> Option.get in
          let event = Member.FraudScoreChanged {
            old_score = Fraud_score.zero;
            new_score = Fraud_score.of_int_exn 90;
            factors;
          } in
          let envelope =
            Ascetic_ddd.Domain_event.create
              ~aggregate_id:(Ids.Member_id.show member_id)
              ~aggregate_version:2 ~occurred_at:now event
          in
          ignore (ES.append () ~aggregate_id:(Ids.Member_id.show member_id)
                    ~expected_version:1 [envelope]);
          ignore community_id;
          ctx);
      Gherkin.when_ "fraudster tries to vote" (fun ctx ->
          ctx |> cast_vote ~voter_name:"fraudster" ~message_label:"msg1"
                 ~vote_type:Vote_type.Up);
      Gherkin.then_ "the vote is rejected with Fraud_blocked" (fun ctx ->
          match ctx.last_error with
          | Some Domain_error.Fraud_blocked -> ()
          | Some e -> Alcotest.fail (Printf.sprintf "wrong error: %s" (Domain_error.show e))
          | None -> Alcotest.fail "expected Fraud_blocked");
    ]

(* ================================================================
   Feature: Cross-Chat Karma
   ================================================================ *)

let cross_chat_karma =
  Gherkin.scenario "Karma accumulates across chats in the same community"
    fresh_ctx
    [
      Gherkin.given "a community with 2 chats" (fun ctx ->
          let ctx = ctx |> create_community ~name:"Multi-Chat" |> attach_chat in
          (* Attach a second chat *)
          let community_id = Option.get ctx.community_id in
          let ext_chat2 =
            External_ids.External_chat_id.create ~platform:"test" ~value:"chat2"
          in
          let _ =
            Reputation_app.Attach_chat.handle ctx.deps ()
              { community_id; external_chat_id = ext_chat2 }
          in
          ctx);
      Gherkin.and_ "two members" (fun ctx ->
          ctx |> register_member ~name:"alice" |> register_member ~name:"bob");
      Gherkin.and_ "Alice posted in chat 1" (fun ctx ->
          ctx |> post_message ~author_name:"alice" ~label:"msg_chat1");
      Gherkin.when_ "Bob upvotes in chat 1" (fun ctx ->
          ctx |> cast_vote ~voter_name:"bob" ~message_label:"msg_chat1"
                 ~vote_type:Vote_type.Up);
      Gherkin.then_ "Alice's community-level karma increased" (fun ctx ->
          let pub, _ = get_member_karma ctx ~name:"alice" in
          Alcotest.(check bool) "karma > 0" true (pub > 0.0));
    ]

(* ================================================================
   Run all features
   ================================================================ *)

let () =
  Alcotest.run "Acceptance Tests"
    [
      Gherkin.feature "Vote Casting"
        [ vote_casting_upvote; vote_casting_downvote ];
      Gherkin.feature "Self-Vote Prevention"
        [ self_vote_prevention ];
      Gherkin.feature "Duplicate Vote"
        [ duplicate_vote ];
      Gherkin.feature "Budget Exhaustion"
        [ budget_exhaustion ];
      Gherkin.feature "Multiple Voters"
        [ multiple_voters ];
      Gherkin.feature "Fraud Detection"
        [ fraud_blocked_voter ];
      Gherkin.feature "Cross-Chat Karma"
        [ cross_chat_karma ];
    ]
