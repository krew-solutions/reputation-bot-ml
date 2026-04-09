(** Register a new member in a community. *)

open Reputation_domain
open Ascetic_ddd.Result_ext

type t = {
  external_user_id : External_ids.External_user_id.t;
  community_id : Ids.Community_id.t;
}

type result = { member_id : Ids.Member_id.t }

let handle (type uow) (deps : uow Deps.t) (uow : uow) (cmd : t) =
  let (module MemberRepo) = deps.member_repo in
  let (module IdMapping) = deps.id_mapping in
  let (module EventStore) = deps.event_store in
  let (module Clock) = deps.clock in
  let now = Clock.now () in
  (* Check if already registered *)
  let* existing =
    IdMapping.find_member_id uow cmd.external_user_id cmd.community_id
    |> map_error (fun e -> Domain_error.Invalid_argument e)
  in
  match existing with
  | Some member_id -> Ok { member_id }
  | None ->
      let* member_id =
        MemberRepo.next_id uow
        |> map_error (fun e -> Domain_error.Invalid_argument e)
      in
      let member =
        Member.register ~id:member_id ~community_id:cmd.community_id ~now
      in
      let* () =
        EventStore.append uow
          ~aggregate_id:(Ids.Member_id.show member_id)
          ~expected_version:0
          (Member.uncommitted_events member)
      in
      let* () =
        IdMapping.save_member_mapping uow cmd.external_user_id member_id
          cmd.community_id
        |> map_error (fun e -> Domain_error.Invalid_argument e)
      in
      Ok { member_id }
