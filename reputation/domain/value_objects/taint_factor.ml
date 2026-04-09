(** Taint factor — fraud classification to multiplier. *)

type t = float [@@deriving show, eq]

let of_fraud_score score =
  match Fraud_score.classify score with
  | Clean -> 1.0
  | Suspicious -> 0.7
  | LikelyFraud -> 0.3
  | ConfirmedFraud -> 0.0

let to_float t = t
let is_blocked t = t = 0.0
