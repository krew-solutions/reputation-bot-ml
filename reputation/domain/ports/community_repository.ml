(** Community repository port. *)

module type S = sig
  type uow

  val find_by_id :
    uow -> Ids.Community_id.t -> (Community.t option, string) result

  val save :
    uow ->
    Community.t ->
    expected_version:int ->
    (unit, Domain_error.t) result

  val next_id : uow -> (Ids.Community_id.t, string) result
end
