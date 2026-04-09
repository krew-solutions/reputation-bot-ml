(** Vote weight — computed from vote type and voting power. *)

type t = Ascetic_ddd.Decimal.t [@@deriving show, eq, ord]

let compute ~(vote_type : Vote_type.t) ~(voting_power : Voting_power.t) =
  let base = Vote_type.base_value vote_type in
  Ascetic_ddd.Decimal.of_float
    (Float.of_int base *. Voting_power.multiplier voting_power)

let to_decimal t = t
let to_karma t = Karma.of_decimal t
