(** Fraud factors — five sub-scores that sum to FraudScore.

    Each factor detects a specific type of fraudulent behavior:
    - reciprocal_voting: A<->B mutual upvote pairs
    - vote_concentration: Herfindahl index on vote distribution
    - ring_participation: cycle detection (A->B->C->A)
    - karma_ratio_anomaly: high karma with few unique voters
    - velocity_anomaly: rapid voting bursts

    {2 Contracts}
    - Each individual factor is clamped to [\[0, 100\]]
    - [to_fraud_score] sums all factors, capped at 100
    - [zero] has all factors at 0 *)

type t [@@deriving show, eq]

val create :
  reciprocal_voting:int ->
  vote_concentration:int ->
  ring_participation:int ->
  karma_ratio_anomaly:int ->
  velocity_anomaly:int ->
  t

val reciprocal_voting : t -> int
val vote_concentration : t -> int
val ring_participation : t -> int
val karma_ratio_anomaly : t -> int
val velocity_anomaly : t -> int
val to_fraud_score : t -> Fraud_score.t
val zero : t
