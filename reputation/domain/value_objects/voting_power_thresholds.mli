(** Configurable thresholds for voting power tiers.

    {2 Invariant}
    [regular < trusted < elder] — enforced by smart constructor.

    {2 Contracts}
    - [create] returns [None] if thresholds are not strictly increasing
    - [derive_power] maps effective karma to the correct tier *)

type t [@@deriving show, eq]

val create :
  regular:Karma.t -> trusted:Karma.t -> elder:Karma.t -> t option

val default : t
(** Default thresholds: regular=10, trusted=100, elder=500. *)

val derive_power : t -> effective_karma:Karma.t -> Voting_power.t

val regular : t -> Karma.t
val trusted : t -> Karma.t
val elder : t -> Karma.t
