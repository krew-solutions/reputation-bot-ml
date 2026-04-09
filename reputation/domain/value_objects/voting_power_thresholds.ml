(** Configurable voting power thresholds. *)

module D = Ascetic_ddd.Decimal

type t = {
  regular : Karma.t;
  trusted : Karma.t;
  elder : Karma.t;
}
[@@deriving show, eq]

let create ~regular ~trusted ~elder =
  if D.compare regular trusted < 0 && D.compare trusted elder < 0 then
    Some { regular; trusted; elder }
  else None

let default =
  {
    regular = Karma.of_int 10;
    trusted = Karma.of_int 100;
    elder = Karma.of_int 500;
  }

let regular t = t.regular
let trusted t = t.trusted
let elder t = t.elder

let derive_power t ~effective_karma =
  if D.compare effective_karma t.elder >= 0 then Voting_power.elder
  else if D.compare effective_karma t.trusted >= 0 then Voting_power.trusted
  else if D.compare effective_karma t.regular >= 0 then Voting_power.regular
  else Voting_power.newcomer
