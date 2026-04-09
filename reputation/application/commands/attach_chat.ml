(** Attach a chat to a community. *)

open Reputation_domain
open Ascetic_ddd.Result_ext

type t = {
  community_id : Ids.Community_id.t;
  external_chat_id : External_ids.External_chat_id.t;
}

type result = { chat_id : Ids.Chat_id.t }

let handle (type uow) (deps : uow Deps.t) (uow : uow) (cmd : t) =
  let (module CommunityRepo) = deps.community_repo in
  let (module ChatRepo) = deps.chat_repo in
  let (module EventPub) = deps.event_publisher in
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
  (* Create chat *)
  let* chat_id =
    ChatRepo.next_id uow
    |> map_error (fun e -> Domain_error.Invalid_argument e)
  in
  let chat =
    Chat.create ~id:chat_id ~community_id:cmd.community_id
      ~external_chat_id:cmd.external_chat_id
  in
  let* () = ChatRepo.save uow chat ~expected_version:0 in
  (* Attach to community *)
  let community_version = Community.version community in
  let* community = Community.attach_chat community ~chat_id ~now in
  let* () =
    CommunityRepo.save uow community ~expected_version:community_version
  in
  let* () =
    EventPub.publish uow (Community.uncommitted_events community)
    |> map_error (fun e -> Domain_error.Invalid_argument e)
  in
  Ok { chat_id }
