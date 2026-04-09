(** Event store port — for event-sourced aggregates (Member). *)

module type S = sig
  type uow

  val append :
    uow ->
    aggregate_id:string ->
    expected_version:int ->
    Member.event Ascetic_ddd.Domain_event.t list ->
    (unit, Domain_error.t) result

  val load_events :
    uow ->
    aggregate_id:string ->
    since_version:int ->
    (Member.event Ascetic_ddd.Domain_event.t list, string) result

  val save_snapshot :
    uow ->
    aggregate_id:string ->
    version:int ->
    data:string ->
    (unit, string) result

  val load_snapshot :
    uow ->
    aggregate_id:string ->
    ((int * string) option, string) result
end
