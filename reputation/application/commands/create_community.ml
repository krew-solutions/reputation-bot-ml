(** Create a new community. *)

open Reputation_domain
open Ascetic_ddd.Result_ext

type t = {
  name : string;
  settings : Group_settings.t option;
}

type result = { community_id : Ids.Community_id.t }

let handle (type uow) (deps : uow Deps.t) (uow : uow) (cmd : t) =
  let (module CommunityRepo) = deps.community_repo in
  let (module EventPub) = deps.event_publisher in
  let (module Clock) = deps.clock in
  let now = Clock.now () in
  let settings =
    match cmd.settings with Some s -> s | None -> Group_settings.default
  in
  let* community_id =
    CommunityRepo.next_id uow
    |> map_error (fun e -> Domain_error.Invalid_argument e)
  in
  let community =
    Community.create ~id:community_id ~name:cmd.name ~settings ~now
  in
  let* () = CommunityRepo.save uow community ~expected_version:0 in
  let* () =
    EventPub.publish uow (Community.uncommitted_events community)
    |> map_error (fun e -> Domain_error.Invalid_argument e)
  in
  Ok { community_id }
