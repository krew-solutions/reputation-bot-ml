(** Karma calculation — pure domain service.

    Computes the karma delta from vote/reaction weights and taint factor. *)

let compute_vote_karma_delta ~(weight : Vote_weight.t)
    ~(taint_factor : Taint_factor.t) =
  let w = Vote_weight.to_decimal weight in
  let tf = Taint_factor.to_float taint_factor in
  Ascetic_ddd.Decimal.of_float (Ascetic_ddd.Decimal.to_float w *. tf)

let compute_reaction_karma_delta ~(weight : Reaction_weight.t)
    ~(taint_factor : Taint_factor.t) =
  let w = Reaction_weight.to_decimal weight in
  let tf = Taint_factor.to_float taint_factor in
  Ascetic_ddd.Decimal.of_float (Ascetic_ddd.Decimal.to_float w *. tf)
