(** Message score — accumulated from votes and reactions. *)

type t = Ascetic_ddd.Decimal.t [@@deriving show, eq, ord]

let zero = Ascetic_ddd.Decimal.zero

let add_vote_weight t (weight : Vote_weight.t) =
  Ascetic_ddd.Decimal.add t (Vote_weight.to_decimal weight)

let add_reaction_weight t (weight : Reaction_weight.t) =
  Ascetic_ddd.Decimal.add t (Reaction_weight.to_decimal weight)

let to_decimal t = t
let to_float = Ascetic_ddd.Decimal.to_float
