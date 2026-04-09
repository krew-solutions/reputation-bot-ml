(** Reaction percentile — configurable threshold for reaction voting access.

    Only members whose reputation is above the configured percentile
    (among members with non-default reputation) may vote via reactions.
    Default threshold: 75%. *)

type t = {
  threshold_pct : int;  (** 0-100, the percentile threshold *)
  exclude_default : bool;  (** Whether to exclude members with default reputation *)
}
[@@deriving show, eq]

let create ?(exclude_default = true) threshold_pct =
  if threshold_pct >= 0 && threshold_pct <= 100 then
    Some { threshold_pct; exclude_default }
  else None

let default = { threshold_pct = 75; exclude_default = true }

let threshold_pct t = t.threshold_pct
let exclude_default t = t.exclude_default

let is_above_threshold ~member_percentile t =
  member_percentile >= Float.of_int t.threshold_pct
