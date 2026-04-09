(** Voting window — time period during which votes on a message are accepted.

    After the window closes, no more votes can be cast on the message. *)

type t = { duration : Ptime.span }

let pp fmt t =
  Format.fprintf fmt "{ duration = %a }" Ptime.Span.pp t.duration

let show t = Format.asprintf "%a" pp t

let equal a b = Ptime.Span.equal a.duration b.duration

let create ~duration = { duration }

let default =
  { duration = Ptime.Span.of_int_s (48 * 60 * 60) }  (* 48 hours *)

let duration t = t.duration

let is_open t ~message_created_at ~now =
  match Ptime.add_span message_created_at t.duration with
  | Some deadline -> Ptime.is_later deadline ~than:now
  | None -> false
