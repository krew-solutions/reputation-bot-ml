(** Event publisher port — dispatches domain events. *)

module type S = sig
  type uow

  val publish :
    uow ->
    Domain_events.t Ascetic_ddd.Domain_event.t list ->
    (unit, string) result
end
