open Reputation_domain
open Test_support

let deps = In_memory_repos.make_deps ()

let ext_voter =
  External_ids.External_user_id.create ~platform:"telegram" ~value:"voter1"

let ext_author =
  External_ids.External_user_id.create ~platform:"telegram" ~value:"author1"

let ext_msg =
  External_ids.External_message_id.create ~platform:"telegram" ~value:"msg1"

let ext_chat =
  External_ids.External_chat_id.create ~platform:"telegram" ~value:"chat1"

(** Set up: community, chat, two members, one message. *)
let setup () =
  In_memory_repos.clear_all ();
  (* Create community *)
  let community_id =
    Reputation_app.Create_community.handle deps ()
      { name = "Test"; settings = None }
    |> Result.get_ok
    |> fun r -> r.community_id
  in
  (* Attach chat *)
  let chat_id =
    Reputation_app.Attach_chat.handle deps ()
      { community_id; external_chat_id = ext_chat }
    |> Result.get_ok
    |> fun r -> r.chat_id
  in
  (* Register author *)
  let author_id =
    Reputation_app.Register_member.handle deps ()
      { external_user_id = ext_author; community_id }
    |> Result.get_ok
    |> fun r -> r.member_id
  in
  (* Register voter *)
  let voter_id =
    Reputation_app.Register_member.handle deps ()
      { external_user_id = ext_voter; community_id }
    |> Result.get_ok
    |> fun r -> r.member_id
  in
  (* Record message *)
  let message_id =
    Reputation_app.Record_message.handle deps ()
      {
        external_message_id = ext_msg;
        author_member_id = author_id;
        chat_id;
      }
    |> Result.get_ok
    |> fun r -> r.message_id
  in
  (community_id, voter_id, author_id, message_id)

let test_cast_upvote () =
  let (community_id, voter_id, _author_id, message_id) = setup () in
  let result =
    Reputation_app.Cast_vote.handle deps ()
      {
        message_id;
        voter_id;
        vote_type = Vote_type.Up;
        community_id;
      }
  in
  match result with
  | Ok r ->
      Alcotest.(check bool) "positive karma delta" true
        (Karma.is_positive r.karma_delta);
      Alcotest.(check bool) "author karma increased" true
        (Karma.is_positive r.new_author_public_karma)
  | Error e -> Alcotest.fail (Domain_error.show e)

let test_cast_downvote () =
  let (community_id, voter_id, _author_id, message_id) = setup () in
  let result =
    Reputation_app.Cast_vote.handle deps ()
      {
        message_id;
        voter_id;
        vote_type = Vote_type.Down;
        community_id;
      }
  in
  match result with
  | Ok r ->
      Alcotest.(check bool) "negative karma delta" true
        (Karma.is_negative r.karma_delta)
  | Error e -> Alcotest.fail (Domain_error.show e)

let test_self_vote_rejected () =
  let (community_id, _voter_id, author_id, message_id) = setup () in
  let result =
    Reputation_app.Cast_vote.handle deps ()
      {
        message_id;
        voter_id = author_id;  (* Author votes on own message *)
        vote_type = Vote_type.Up;
        community_id;
      }
  in
  match result with
  | Ok _ -> Alcotest.fail "should reject self-vote"
  | Error Domain_error.Self_vote_prohibited -> ()
  | Error e -> Alcotest.fail (Printf.sprintf "wrong error: %s" (Domain_error.show e))

let test_duplicate_vote_rejected () =
  let (community_id, voter_id, _author_id, message_id) = setup () in
  let _first =
    Reputation_app.Cast_vote.handle deps ()
      {
        message_id;
        voter_id;
        vote_type = Vote_type.Up;
        community_id;
      }
    |> Result.get_ok
  in
  let result =
    Reputation_app.Cast_vote.handle deps ()
      {
        message_id;
        voter_id;
        vote_type = Vote_type.Up;
        community_id;
      }
  in
  match result with
  | Ok _ -> Alcotest.fail "should reject duplicate"
  | Error Domain_error.Duplicate_vote -> ()
  | Error e -> Alcotest.fail (Printf.sprintf "wrong error: %s" (Domain_error.show e))

let test_karma_query_after_vote () =
  let (community_id, voter_id, author_id, message_id) = setup () in
  let _vote =
    Reputation_app.Cast_vote.handle deps ()
      {
        message_id;
        voter_id;
        vote_type = Vote_type.Up;
        community_id;
      }
    |> Result.get_ok
  in
  let karma_result =
    Reputation_app.Get_member_karma.handle deps ()
      { member_id = author_id }
  in
  match karma_result with
  | Ok r ->
      Alcotest.(check bool) "public karma > 0" true
        (Karma.is_positive r.public_karma)
  | Error e -> Alcotest.fail (Domain_error.show e)

let () =
  Alcotest.run "Cast_vote"
    [
      ( "handler",
        [
          Alcotest.test_case "upvote" `Quick test_cast_upvote;
          Alcotest.test_case "downvote" `Quick test_cast_downvote;
          Alcotest.test_case "self-vote" `Quick test_self_vote_rejected;
          Alcotest.test_case "duplicate" `Quick test_duplicate_vote_rejected;
          Alcotest.test_case "karma after vote" `Quick
            test_karma_query_after_vote;
        ] );
    ]
