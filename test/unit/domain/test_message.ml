module Msg = Reputation_domain.Message
module VT = Reputation_domain.Vote_type
module VW = Reputation_domain.Vote_weight
module VP = Reputation_domain.Voting_power
module RT = Reputation_domain.Reaction_type
module RW = Reputation_domain.Reaction_weight
module DE = Reputation_domain.Domain_error
module Ids = Reputation_domain.Ids

let msg_id = Ids.Message_id.of_int 1
let author_id = Ids.Member_id.of_int 1
let voter_id = Ids.Member_id.of_int 2
let voter2_id = Ids.Member_id.of_int 3
let chat_id = Ids.Chat_id.of_int 1
let vote_id = Ids.Vote_id.of_int 1
let vote2_id = Ids.Vote_id.of_int 2
let reaction_id = Ids.Reaction_id.of_int 1
let now = Ptime.of_float_s 1_700_000_000.0 |> Option.get
let voting_window = Reputation_domain.Voting_window.default

let make_message () =
  Msg.create ~id:msg_id ~author_id ~chat_id ~created_at:now

let weight = VW.compute ~vote_type:VT.Up ~voting_power:VP.regular

let test_add_vote_ok () =
  let msg = make_message () in
  match
    Msg.add_vote msg ~vote_id ~voter_id ~vote_type:VT.Up ~weight ~now
      ~voting_window
  with
  | Ok msg ->
      Alcotest.(check int) "1 vote" 1 (List.length (Msg.votes msg));
      Alcotest.(check int) "version 1" 1 (Msg.version msg);
      Alcotest.(check int) "1 event" 1
        (List.length (Msg.uncommitted_events msg))
  | Error e -> Alcotest.fail (DE.show e)

let test_self_vote_prohibited () =
  let msg = make_message () in
  match
    Msg.add_vote msg ~vote_id ~voter_id:author_id ~vote_type:VT.Up ~weight
      ~now ~voting_window
  with
  | Ok _ -> Alcotest.fail "should reject self-vote"
  | Error DE.Self_vote_prohibited -> ()
  | Error e -> Alcotest.fail (Printf.sprintf "wrong error: %s" (DE.show e))

let test_duplicate_vote () =
  let msg = make_message () in
  let msg =
    Msg.add_vote msg ~vote_id ~voter_id ~vote_type:VT.Up ~weight ~now
      ~voting_window
    |> Result.get_ok
  in
  match
    Msg.add_vote msg ~vote_id:vote2_id ~voter_id ~vote_type:VT.Up ~weight
      ~now ~voting_window
  with
  | Ok _ -> Alcotest.fail "should reject duplicate"
  | Error DE.Duplicate_vote -> ()
  | Error e -> Alcotest.fail (Printf.sprintf "wrong error: %s" (DE.show e))

let test_voting_window_closed () =
  let msg = make_message () in
  let far_future =
    Ptime.add_span now (Ptime.Span.of_int_s (49 * 3600)) |> Option.get
  in
  match
    Msg.add_vote msg ~vote_id ~voter_id ~vote_type:VT.Up ~weight
      ~now:far_future ~voting_window
  with
  | Ok _ -> Alcotest.fail "should reject after window"
  | Error DE.Voting_window_closed -> ()
  | Error e -> Alcotest.fail (Printf.sprintf "wrong error: %s" (DE.show e))

let test_multiple_voters () =
  let msg = make_message () in
  let msg =
    Msg.add_vote msg ~vote_id ~voter_id ~vote_type:VT.Up ~weight ~now
      ~voting_window
    |> Result.get_ok
  in
  let msg =
    Msg.add_vote msg ~vote_id:vote2_id ~voter_id:voter2_id ~vote_type:VT.Down
      ~weight ~now ~voting_window
    |> Result.get_ok
  in
  Alcotest.(check int) "2 votes" 2 (List.length (Msg.votes msg));
  Alcotest.(check int) "2 events" 2
    (List.length (Msg.uncommitted_events msg))

let test_add_reaction_ok () =
  let msg = make_message () in
  let rt = RT.create ~emoji:"\u{1F44D}" ~direction:RT.Positive in
  let rw = RW.compute ~reaction_type:rt ~voting_power:VP.regular ~coefficient:0.1 in
  match
    Msg.add_reaction msg ~reaction_id ~reactor_id:voter_id ~reaction_type:rt
      ~weight:rw ~now ~voting_window
  with
  | Ok msg ->
      Alcotest.(check int) "1 reaction" 1 (List.length (Msg.reactions msg))
  | Error e -> Alcotest.fail (DE.show e)

let test_self_reaction_prohibited () =
  let msg = make_message () in
  let rt = RT.create ~emoji:"\u{1F44D}" ~direction:RT.Positive in
  let rw = RW.compute ~reaction_type:rt ~voting_power:VP.regular ~coefficient:0.1 in
  match
    Msg.add_reaction msg ~reaction_id ~reactor_id:author_id ~reaction_type:rt
      ~weight:rw ~now ~voting_window
  with
  | Ok _ -> Alcotest.fail "should reject self-reaction"
  | Error DE.Self_vote_prohibited -> ()
  | Error e -> Alcotest.fail (Printf.sprintf "wrong error: %s" (DE.show e))

let test_duplicate_reaction () =
  let msg = make_message () in
  let rt = RT.create ~emoji:"\u{1F44D}" ~direction:RT.Positive in
  let rw = RW.compute ~reaction_type:rt ~voting_power:VP.regular ~coefficient:0.1 in
  let msg =
    Msg.add_reaction msg ~reaction_id ~reactor_id:voter_id ~reaction_type:rt
      ~weight:rw ~now ~voting_window
    |> Result.get_ok
  in
  let reaction2_id = Ids.Reaction_id.of_int 2 in
  match
    Msg.add_reaction msg ~reaction_id:reaction2_id ~reactor_id:voter_id
      ~reaction_type:rt ~weight:rw ~now ~voting_window
  with
  | Ok _ -> Alcotest.fail "should reject duplicate reaction"
  | Error DE.Duplicate_reaction -> ()
  | Error e -> Alcotest.fail (Printf.sprintf "wrong error: %s" (DE.show e))

let test_remove_reaction () =
  let msg = make_message () in
  let rt = RT.create ~emoji:"\u{1F44D}" ~direction:RT.Positive in
  let rw = RW.compute ~reaction_type:rt ~voting_power:VP.regular ~coefficient:0.1 in
  let msg =
    Msg.add_reaction msg ~reaction_id ~reactor_id:voter_id ~reaction_type:rt
      ~weight:rw ~now ~voting_window
    |> Result.get_ok
  in
  match Msg.remove_reaction msg ~reactor_id:voter_id ~emoji:"\u{1F44D}" with
  | Ok msg ->
      Alcotest.(check int) "0 reactions" 0 (List.length (Msg.reactions msg))
  | Error e -> Alcotest.fail (DE.show e)

let () =
  Alcotest.run "Message"
    [
      ( "votes",
        [
          Alcotest.test_case "add vote" `Quick test_add_vote_ok;
          Alcotest.test_case "self vote" `Quick test_self_vote_prohibited;
          Alcotest.test_case "duplicate vote" `Quick test_duplicate_vote;
          Alcotest.test_case "window closed" `Quick test_voting_window_closed;
          Alcotest.test_case "multiple voters" `Quick test_multiple_voters;
        ] );
      ( "reactions",
        [
          Alcotest.test_case "add reaction" `Quick test_add_reaction_ok;
          Alcotest.test_case "self reaction" `Quick test_self_reaction_prohibited;
          Alcotest.test_case "duplicate reaction" `Quick test_duplicate_reaction;
          Alcotest.test_case "remove reaction" `Quick test_remove_reaction;
        ] );
    ]
