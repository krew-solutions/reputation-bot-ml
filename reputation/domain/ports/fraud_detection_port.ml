(** Fraud detection port — calculates fraud factors from external analysis. *)

module type S = sig
  type uow

  val calculate_fraud_factors :
    uow ->
    Ids.Member_id.t ->
    Ids.Community_id.t ->
    (Fraud_factors.t, string) result

  val detect_voting_rings :
    uow ->
    Ids.Community_id.t ->
    (Ids.Member_id.t list list, string) result
    (** Returns a list of rings, each ring is a list of member IDs. *)
end
