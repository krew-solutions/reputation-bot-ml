(** Voting power penalty — derived from fraud score.

    Applies a multiplier penalty to voting power.
    Confirmed fraudsters get multiplier = 0.0 (fully blocked). *)

type t = { multiplier : float } [@@deriving show, eq]

let of_fraud_score score =
  match Fraud_score.classify score with
  | Clean -> { multiplier = 1.0 }
  | Suspicious -> { multiplier = 0.7 }
  | LikelyFraud -> { multiplier = 0.3 }
  | ConfirmedFraud -> { multiplier = 0.0 }

let multiplier t = t.multiplier
let is_blocked t = t.multiplier = 0.0

let apply t (power : Voting_power.t) =
  let base_mult = Voting_power.multiplier power in
  let penalized_mult = base_mult *. t.multiplier in
  { Voting_power.tier = Voting_power.tier power; multiplier = penalized_mult }
