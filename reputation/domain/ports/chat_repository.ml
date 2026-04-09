(** Chat repository port. *)

module type S = sig
  type uow

  val find_by_id :
    uow -> Ids.Chat_id.t -> (Chat.t option, string) result

  val find_by_external_id :
    uow ->
    External_ids.External_chat_id.t ->
    (Chat.t option, string) result

  val save :
    uow ->
    Chat.t ->
    expected_version:int ->
    (unit, Domain_error.t) result

  val next_id : uow -> (Ids.Chat_id.t, string) result
end
