(** Member repository port. *)

module type S = sig
  type uow

  val find_by_id :
    uow -> Ids.Member_id.t -> (Member.t option, string) result

  val find_by_community :
    uow ->
    Ids.Member_id.t ->
    Ids.Community_id.t ->
    (Member.t option, string) result

  val save :
    uow ->
    Member.t ->
    expected_version:int ->
    (unit, Domain_error.t) result

  val next_id : uow -> (Ids.Member_id.t, string) result
end
