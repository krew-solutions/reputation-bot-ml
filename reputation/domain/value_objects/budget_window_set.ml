(** Budget window set — composite specification for sliding window budget. *)

type t = { windows : Window_spec.t list }

let pp fmt t =
  Format.fprintf fmt "{ windows = [%a] }"
    (Format.pp_print_list ~pp_sep:(fun fmt () -> Format.fprintf fmt "; ")
       Window_spec.pp)
    t.windows

let show t = Format.asprintf "%a" pp t

let equal a b =
  List.length a.windows = List.length b.windows
  && List.for_all2 Window_spec.equal a.windows b.windows

let create windows = { windows }

let default =
  let hour = Ptime.Span.of_int_s (60 * 60) in
  let day = Ptime.Span.of_int_s (24 * 60 * 60) in
  let week = Ptime.Span.of_int_s (7 * 24 * 60 * 60) in
  {
    windows =
      [
        (match Window_spec.create ~name:"hourly" ~duration:hour ~max_actions:5 with
         | Some w -> w | None -> assert false);
        (match Window_spec.create ~name:"daily" ~duration:day ~max_actions:20 with
         | Some w -> w | None -> assert false);
        (match Window_spec.create ~name:"weekly" ~duration:week ~max_actions:100 with
         | Some w -> w | None -> assert false);
      ];
  }

let windows t = t.windows
