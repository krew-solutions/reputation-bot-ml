(** Reaction weight — computed from reaction type, voting power,
    and a configurable reduction coefficient. *)

type t = Ascetic_ddd.Decimal.t [@@deriving show, eq, ord]

let compute ~(reaction_type : Reaction_type.t)
    ~(voting_power : Voting_power.t) ~(coefficient : float) =
  let base = Reaction_type.base_value reaction_type in
  Ascetic_ddd.Decimal.of_float
    (Float.of_int base *. Voting_power.multiplier voting_power *. coefficient)

let to_decimal t = t
let to_karma t = Karma.of_decimal t
