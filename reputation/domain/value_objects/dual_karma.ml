(** Dual Karma value object.

    Invariant: effective <= public (when public >= 0). *)

type t = {
  public : Karma.t;
  effective : Karma.t;
}
[@@deriving show, eq]

let create ~public ~effective =
  if Ascetic_ddd.Decimal.compare effective public <= 0 then
    Some { public; effective }
  else None

let initial = { public = Karma.zero; effective = Karma.zero }

let public t = t.public
let effective t = t.effective

let receive t ~delta ~taint_factor =
  let new_public = Karma.clamp_non_negative (Karma.add t.public delta) in
  let effective_delta =
    Ascetic_ddd.Decimal.of_float
      (Karma.to_float delta *. taint_factor)
  in
  let new_effective =
    Karma.clamp_non_negative (Karma.add t.effective effective_delta)
  in
  (* Maintain invariant: effective <= public *)
  let new_effective =
    if Ascetic_ddd.Decimal.compare new_effective new_public > 0 then
      new_public
    else new_effective
  in
  { public = new_public; effective = new_effective }

let apply_correction t ~effective_delta =
  let new_effective =
    Karma.clamp_non_negative (Karma.add t.effective effective_delta)
  in
  (* Maintain invariant: effective <= public *)
  let new_effective =
    if Ascetic_ddd.Decimal.compare new_effective t.public > 0 then t.public
    else new_effective
  in
  { t with effective = new_effective }
