(** Voting power derived from effective karma.

    Power tier determines the multiplier applied to vote weight. *)

type power_tier = Newcomer | Regular | Trusted | Elder
[@@deriving show, eq, ord]

type t = {
  tier : power_tier;
  multiplier : float;
}
[@@deriving show, eq]

let tier t = t.tier
let multiplier t = t.multiplier

let newcomer = { tier = Newcomer; multiplier = 0.5 }
let regular = { tier = Regular; multiplier = 1.0 }
let trusted = { tier = Trusted; multiplier = 1.5 }
let elder = { tier = Elder; multiplier = 2.0 }
