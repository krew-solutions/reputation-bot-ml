(** Add a reaction to a message.

    Similar to cast_vote but:
    - Uses reaction coefficient from settings
    - Requires voter to be above reaction percentile threshold *)

open Reputation_domain
open Ascetic_ddd.Result_ext

type t = {
  message_id : Ids.Message_id.t;
  reactor_id : Ids.Member_id.t;
  reaction_type : Reaction_type.t;
  community_id : Ids.Community_id.t;
}

type result = {
  karma_delta : Karma.t;
}

let handle (type uow) (deps : uow Deps.t) (uow : uow) (cmd : t) =
  let (module MessageRepo) = deps.message_repo in
  let (module CommunityRepo) = deps.community_repo in
  let (module EventStore) = deps.event_store in
  let (module EventPub) = deps.event_publisher in
  let (module Percentile) = deps.percentile in
  let (module Clock) = deps.clock in
  let now = Clock.now () in
  (* Load community *)
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
  (* Check reaction percentile gate *)
  let rp = Group_settings.reaction_percentile settings in
  let* member_pct =
    Percentile.calculate_percentile uow cmd.reactor_id cmd.community_id
      ~exclude_default:(Reaction_percentile.exclude_default rp)
    |> map_error (fun e -> Domain_error.Invalid_argument e)
  in
  let* () =
    guard
      (Reaction_percentile.is_above_threshold ~member_percentile:member_pct rp)
      ~error:
        (Domain_error.Reaction_percentile_not_reached
           {
             required_pct = Reaction_percentile.threshold_pct rp;
             actual_pct = member_pct;
           })
  in
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
  (* Load reactor *)
  let* reactor = Cast_vote.load_member deps uow cmd.reactor_id in
  let reactor_version = Member.version reactor in
  (* Compute weight *)
  let voting_power =
    Member.effective_voting_power reactor
      ~thresholds:(Group_settings.voting_power_thresholds settings)
  in
  let coefficient = Group_settings.reaction_coefficient settings in
  let weight =
    Reaction_weight.compute ~reaction_type:cmd.reaction_type ~voting_power
      ~coefficient
  in
  (* Add reaction to message *)
  let reaction_id =
    Ids.Reaction_id.of_int (List.length (Message.reactions msg) + 1)
  in
  let* msg =
    Message.add_reaction msg ~reaction_id ~reactor_id:cmd.reactor_id
      ~reaction_type:cmd.reaction_type ~weight ~now
      ~voting_window:(Group_settings.voting_window settings)
  in
  let msg_version = Message.version msg - 1 in
  let* () = MessageRepo.save uow msg ~expected_version:msg_version in
  let* () =
    EventPub.publish uow (Message.uncommitted_events msg)
    |> map_error (fun e -> Domain_error.Invalid_argument e)
  in
  (* Record action in reactor budget *)
  let reactor = Member.record_vote reactor ~now in
  let* () =
    EventStore.append uow
      ~aggregate_id:(Ids.Member_id.show cmd.reactor_id)
      ~expected_version:reactor_version
      (Member.uncommitted_events reactor)
  in
  (* Award karma to author *)
  let author_id = Message.author_id msg in
  let* author = Cast_vote.load_member deps uow author_id in
  let author_version = Member.version author in
  let taint = Taint_factor.of_fraud_score (Member.fraud_score reactor) in
  let karma_delta = Reaction_weight.to_karma weight in
  let author =
    Member.receive_karma author ~delta:karma_delta
      ~taint_factor:(Taint_factor.to_float taint)
      ~source_member_id:cmd.reactor_id ~reason:"reaction" ~now
  in
  let* () =
    EventStore.append uow
      ~aggregate_id:(Ids.Member_id.show author_id)
      ~expected_version:author_version
      (Member.uncommitted_events author)
  in
  Ok { karma_delta }
