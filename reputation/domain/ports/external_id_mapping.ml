(** External ID mapping port.

    Maps platform-specific external IDs to internal domain IDs. *)

module type S = sig
  type uow

  val find_member_id :
    uow ->
    External_ids.External_user_id.t ->
    Ids.Community_id.t ->
    (Ids.Member_id.t option, string) result

  val find_message_id :
    uow ->
    External_ids.External_message_id.t ->
    (Ids.Message_id.t option, string) result

  val save_member_mapping :
    uow ->
    External_ids.External_user_id.t ->
    Ids.Member_id.t ->
    Ids.Community_id.t ->
    (unit, string) result

  val save_message_mapping :
    uow ->
    External_ids.External_message_id.t ->
    Ids.Message_id.t ->
    (unit, string) result
end
