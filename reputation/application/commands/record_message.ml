(** Record a new message in a chat. *)

open Reputation_domain
open Ascetic_ddd.Result_ext

type t = {
  external_message_id : External_ids.External_message_id.t;
  author_member_id : Ids.Member_id.t;
  chat_id : Ids.Chat_id.t;
}

type result = { message_id : Ids.Message_id.t }

let handle (type uow) (deps : uow Deps.t) (uow : uow) (cmd : t) =
  let (module MessageRepo) = deps.message_repo in
  let (module IdMapping) = deps.id_mapping in
  let (module Clock) = deps.clock in
  let now = Clock.now () in
  (* Check if already recorded *)
  let* existing =
    IdMapping.find_message_id uow cmd.external_message_id
    |> map_error (fun e -> Domain_error.Invalid_argument e)
  in
  match existing with
  | Some message_id -> Ok { message_id }
  | None ->
      let* message_id =
        MessageRepo.next_id uow
        |> map_error (fun e -> Domain_error.Invalid_argument e)
      in
      let message =
        Message.create ~id:message_id ~author_id:cmd.author_member_id
          ~chat_id:cmd.chat_id ~created_at:now
      in
      let* () =
        MessageRepo.save uow message ~expected_version:0
      in
      let* () =
        IdMapping.save_message_mapping uow cmd.external_message_id message_id
        |> map_error (fun e -> Domain_error.Invalid_argument e)
      in
      Ok { message_id }
