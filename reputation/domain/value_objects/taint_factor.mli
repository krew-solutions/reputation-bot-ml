(** Taint factor — maps fraud classification to a multiplier.

    Applied to karma deltas: clean source gets full credit,
    confirmed fraud gets zero credit.

    {2 Contracts}
    - [to_float] always returns a value in [\[0.0, 1.0\]]
    - Clean (score < 20):          1.0 (100%)
    - Suspicious (20-49):          0.7 (70%)
    - LikelyFraud (50-79):        0.3 (30%)
    - ConfirmedFraud (score >= 80): 0.0 (0%)
    - [is_blocked t] iff [to_float t = 0.0] *)

type t [@@deriving show, eq]

val of_fraud_score : Fraud_score.t -> t
val to_float : t -> float
val is_blocked : t -> bool
