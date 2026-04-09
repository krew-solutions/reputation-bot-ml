(** Cast a vote on a message — the primary use case.

    Orchestrates: load message + voter + author, check rules,
    add vote to message, award/deduct karma to author,
    record vote action in voter's budget. *)

open Reputation_domain
open Ascetic_ddd.Result_ext

type t = {
  message_id : Ids.Message_id.t;
  voter_id : Ids.Member_id.t;
  vote_type : Vote_type.t;
  community_id : Ids.Community_id.t;
}

type result = {
  karma_delta : Karma.t;
  new_author_public_karma : Karma.t;
}

let load_member (type uow) (deps : uow Deps.t) (uow : uow) member_id =
  let (module EventStore) = deps.event_store in
  let* events =
    EventStore.load_events uow
      ~aggregate_id:(Ids.Member_id.show member_id)
      ~since_version:0
    |> map_error (fun e -> Domain_error.Invalid_argument e)
  in
  match events with
  | [] -> Error (Domain_error.Member_not_found { member_id })
  | first :: _ ->
      let initial_member =
        match first.Ascetic_ddd.Domain_event.payload with
        | Member.Registered { member_id = mid; community_id } ->
            Member.initial_state ~id:mid ~community_id
        | _ ->
            Member.initial_state ~id:member_id
              ~community_id:(Ids.Community_id.of_int 0)
      in
      let member =
        List.fold_left
          (fun state envelope ->
            Member.apply_event state envelope.Ascetic_ddd.Domain_event.payload)
          initial_member events
      in
      Ok (Member.clear_uncommitted_events member)

let handle (type uow) (deps : uow Deps.t) (uow : uow) (cmd : t) =
  let (module MessageRepo) = deps.message_repo in
  let (module CommunityRepo) = deps.community_repo in
  let (module EventStore) = deps.event_store in
  let (module EventPub) = deps.event_publisher in
  let (module Clock) = deps.clock in
  let now = Clock.now () in
  (* Load community for settings *)
  let* community_opt =
    CommunityRepo.find_by_id uow cmd.community_id
    |> map_error (fun e -> Domain_error.Invalid_argument e)
  in
  let* community =
    of_option
      ~error:(Domain_error.Community_not_found { community_id = cmd.community_id })
      community_opt
  in
  let settings = Community.settings community in
  (* Load message *)
  let* msg_opt =
    MessageRepo.find_by_id uow cmd.message_id
    |> map_error (fun e -> Domain_error.Invalid_argument e)
  in
  let* msg =
    of_option
      ~error:(Domain_error.Message_not_found { message_id = cmd.message_id })
      msg_opt
  in
  (* Load voter *)
  let* voter = load_member deps uow cmd.voter_id in
  let voter_version = Member.version voter in
  (* Check voter can vote *)
  let* () =
    Member.can_vote voter ~now
      ~budget_windows:(Group_settings.budget_window_set settings)
  in
  (* Compute voting power and weight *)
  let voting_power =
    Member.effective_voting_power voter
      ~thresholds:(Group_settings.voting_power_thresholds settings)
  in
  let weight = Vote_weight.compute ~vote_type:cmd.vote_type ~voting_power in
  (* Generate vote ID *)
  let vote_id = Ids.Vote_id.of_int (List.length (Message.votes msg) + 1) in
  (* Add vote to message *)
  let* msg =
    Message.add_vote msg ~vote_id ~voter_id:cmd.voter_id
      ~vote_type:cmd.vote_type ~weight ~now
      ~voting_window:(Group_settings.voting_window settings)
  in
  let msg_version = Message.version msg - 1 in
  (* Save message *)
  let* () = MessageRepo.save uow msg ~expected_version:msg_version in
  (* Publish message events *)
  let* () =
    EventPub.publish uow (Message.uncommitted_events msg)
    |> map_error (fun e -> Domain_error.Invalid_argument e)
  in
  (* Record vote in voter's budget *)
  let voter = Member.record_vote voter ~now in
  let* () =
    EventStore.append uow
      ~aggregate_id:(Ids.Member_id.show cmd.voter_id)
      ~expected_version:voter_version
      (Member.uncommitted_events voter)
  in
  (* Award/deduct karma to message author *)
  let author_id = Message.author_id msg in
  let* author = load_member deps uow author_id in
  let author_version = Member.version author in
  let taint = Taint_factor.of_fraud_score (Member.fraud_score voter) in
  let karma_delta = Vote_weight.to_karma weight in
  let reason =
    Printf.sprintf "vote:%s"
      (if cmd.vote_type = Vote_type.Up then "up" else "down")
  in
  let author =
    Member.receive_karma author ~delta:karma_delta
      ~taint_factor:(Taint_factor.to_float taint)
      ~source_member_id:cmd.voter_id ~reason ~now
  in
  let* () =
    EventStore.append uow
      ~aggregate_id:(Ids.Member_id.show author_id)
      ~expected_version:author_version
      (Member.uncommitted_events author)
  in
  Ok
    {
      karma_delta;
      new_author_public_karma = Dual_karma.public (Member.dual_karma author);
    }
