(** Dual Karma value object.

    Separates karma into two tracks:
    - [public]: always grows, shown to the user. Never decremented by fraud.
    - [effective]: used by the system for voting power and leaderboards.
      May be reduced by fraud correction.

    {2 Invariants (enforced at construction and by all operations)}
    - [effective <= public] always holds
    - [public >= 0] after [receive] (clamped)
    - [effective >= 0] always (clamped)

    {2 Contracts}
    - [receive ~delta ~taint_factor]: public += delta, effective += delta * taint_factor
    - [apply_correction ~effective_delta]: only effective changes, public untouched
    - Both operations preserve the [effective <= public] invariant *)

type t [@@deriving show, eq]

val create : public:Karma.t -> effective:Karma.t -> t option
(** Returns [None] if [effective > public]. *)

val initial : t
(** Both public and effective are zero. *)

val public : t -> Karma.t
val effective : t -> Karma.t

val receive : t -> delta:Karma.t -> taint_factor:float -> t
(** [taint_factor] must be in [\[0.0, 1.0\]]. *)

val apply_correction : t -> effective_delta:Karma.t -> t
(** Adjusts only effective karma. Public karma is never touched. *)
