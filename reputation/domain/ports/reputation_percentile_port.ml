(** Reputation percentile port.

    Calculates a member's percentile rank within their community.
    Members with default (zero) reputation are excluded from the
    calculation when configured. *)

module type S = sig
  type uow

  val calculate_percentile :
    uow ->
    Ids.Member_id.t ->
    Ids.Community_id.t ->
    exclude_default:bool ->
    (float, string) result
    (** Returns the member's percentile (0.0 to 100.0).
        Returns 0.0 if member is not found or community has no
        members with non-default reputation. *)
end
