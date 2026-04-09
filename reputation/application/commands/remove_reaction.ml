(** Remove a reaction from a message. *)

open Reputation_domain
open Ascetic_ddd.Result_ext

type t = {
  message_id : Ids.Message_id.t;
  reactor_id : Ids.Member_id.t;
  emoji : string;
}

let handle (type uow) (deps : uow Deps.t) (uow : uow) (cmd : t) =
  let (module MessageRepo) = deps.message_repo in
  let (module EventPub) = deps.event_publisher in
  let* msg_opt =
    MessageRepo.find_by_id uow cmd.message_id
    |> map_error (fun e -> Domain_error.Invalid_argument e)
  in
  let* msg =
    of_option
      ~error:(Domain_error.Message_not_found { message_id = cmd.message_id })
      msg_opt
  in
  let msg_version = Message.version msg in
  let* msg =
    Message.remove_reaction msg ~reactor_id:cmd.reactor_id ~emoji:cmd.emoji
  in
  let* () = MessageRepo.save uow msg ~expected_version:msg_version in
  let* () =
    EventPub.publish uow (Message.uncommitted_events msg)
    |> map_error (fun e -> Domain_error.Invalid_argument e)
  in
  Ok ()
