(** Karma value object.

    Wraps [Decimal.t] with domain-specific semantics.
    Karma may be negative (effective karma after fraud correction)
    or non-negative (public karma). *)

type t = Ascetic_ddd.Decimal.t [@@deriving show, eq, ord]

let zero = Ascetic_ddd.Decimal.zero
let of_decimal d = d
let to_decimal t = t
let of_int = Ascetic_ddd.Decimal.of_int
let of_string = Ascetic_ddd.Decimal.of_string
let to_string = Ascetic_ddd.Decimal.to_string
let add = Ascetic_ddd.Decimal.add
let sub = Ascetic_ddd.Decimal.sub
let scale = Ascetic_ddd.Decimal.scale
let is_zero = Ascetic_ddd.Decimal.is_zero
let is_positive = Ascetic_ddd.Decimal.is_positive
let is_negative = Ascetic_ddd.Decimal.is_negative
let is_non_negative = Ascetic_ddd.Decimal.is_non_negative
let clamp_non_negative = Ascetic_ddd.Decimal.clamp_non_negative
let to_float = Ascetic_ddd.Decimal.to_float
let mul = Ascetic_ddd.Decimal.mul
