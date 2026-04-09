(** Fraud factors — five sub-scores. *)

type t = {
  reciprocal_voting : int;
  vote_concentration : int;
  ring_participation : int;
  karma_ratio_anomaly : int;
  velocity_anomaly : int;
}
[@@deriving show, eq]

let clamp v = Int.max 0 (Int.min 100 v)

let create ~reciprocal_voting ~vote_concentration ~ring_participation
    ~karma_ratio_anomaly ~velocity_anomaly =
  {
    reciprocal_voting = clamp reciprocal_voting;
    vote_concentration = clamp vote_concentration;
    ring_participation = clamp ring_participation;
    karma_ratio_anomaly = clamp karma_ratio_anomaly;
    velocity_anomaly = clamp velocity_anomaly;
  }

let reciprocal_voting t = t.reciprocal_voting
let vote_concentration t = t.vote_concentration
let ring_participation t = t.ring_participation
let karma_ratio_anomaly t = t.karma_ratio_anomaly
let velocity_anomaly t = t.velocity_anomaly

let zero =
  {
    reciprocal_voting = 0;
    vote_concentration = 0;
    ring_participation = 0;
    karma_ratio_anomaly = 0;
    velocity_anomaly = 0;
  }

let to_fraud_score t =
  let total =
    t.reciprocal_voting + t.vote_concentration + t.ring_participation
    + t.karma_ratio_anomaly + t.velocity_anomaly
  in
  Fraud_score.of_int_clamped total
