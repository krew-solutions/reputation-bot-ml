(** Sliding window budget — tracks action timestamps against budget windows.

    Pure functional: takes the current time as parameter,
    returns new state. No internal mutation. *)

type t [@@deriving show, eq]

val empty : t
(** No actions recorded. *)

val check :
  t ->
  now:Ptime.t ->
  budget:Budget_window_set.t ->
  (unit, Domain_error.t) result
(** [check t ~now ~budget] returns [Ok ()] if all windows have capacity,
    or [Error (Budget_exhausted window_name)] for the first violated window. *)

val record_action : t -> now:Ptime.t -> t
(** [record_action t ~now] records an action at the current time. *)

val prune : t -> now:Ptime.t -> budget:Budget_window_set.t -> t
(** Remove timestamps older than the largest window duration. *)

val action_count_in_window : t -> now:Ptime.t -> Window_spec.t -> int
(** Count actions within a specific window ending at [now]. *)

val export_timestamps : t -> Ptime.t list
(** For persistence. *)

val import_timestamps : Ptime.t list -> t
(** For reconstitution from persistence. *)
