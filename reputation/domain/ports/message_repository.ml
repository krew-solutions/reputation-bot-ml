(** Message repository port. *)

module type S = sig
  type uow

  val find_by_id :
    uow -> Ids.Message_id.t -> (Message.t option, string) result

  val save :
    uow ->
    Message.t ->
    expected_version:int ->
    (unit, Domain_error.t) result

  val next_id : uow -> (Ids.Message_id.t, string) result
end
