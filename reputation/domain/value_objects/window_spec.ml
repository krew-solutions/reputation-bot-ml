(** Window specification — a single sliding window rule.

    Acts as a Specification: [is_exhausted] checks whether the
    action count within the window exceeds the maximum allowed. *)

type t = {
  name : string;
  duration : Ptime.span;
  max_actions : int;
}

let pp_ptime_span fmt span = Format.fprintf fmt "%a" Ptime.Span.pp span

let pp fmt t =
  Format.fprintf fmt "{ name = %S; duration = %a; max_actions = %d }"
    t.name pp_ptime_span t.duration t.max_actions

let show t = Format.asprintf "%a" pp t

let equal a b =
  String.equal a.name b.name
  && Ptime.Span.equal a.duration b.duration
  && Int.equal a.max_actions b.max_actions

let create ~name ~duration ~max_actions =
  if max_actions > 0 then Some { name; duration; max_actions } else None

let name t = t.name
let duration t = t.duration
let max_actions t = t.max_actions

let is_exhausted t ~current_count =
  current_count >= t.max_actions
