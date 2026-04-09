(** Fraud scoring — pure domain service.

    Converts [Fraud_factors] into a [Fraud_score]. *)

let score_from_factors (factors : Fraud_factors.t) : Fraud_score.t =
  Fraud_factors.to_fraud_score factors
