(** Sliding window budget — pure functional implementation. *)

type t = { timestamps : Ptime.t list }

let pp fmt t =
  Format.fprintf fmt "{ timestamps = [%d items] }" (List.length t.timestamps)

let show t = Format.asprintf "%a" pp t

let equal a b =
  List.length a.timestamps = List.length b.timestamps
  && List.for_all2 Ptime.equal a.timestamps b.timestamps

let empty = { timestamps = [] }

let action_count_in_window t ~now window =
  let duration = Window_spec.duration window in
  let window_start =
    match Ptime.sub_span now duration with
    | Some s -> s
    | None -> Ptime.epoch
  in
  List.length
    (List.filter
       (fun ts -> Ptime.is_later ts ~than:window_start || Ptime.equal ts window_start)
       t.timestamps)

let check t ~now ~budget =
  let open Ascetic_ddd.Result_ext in
  let windows = Budget_window_set.windows budget in
  traverse
    (fun window ->
      let count = action_count_in_window t ~now window in
      if Window_spec.is_exhausted window ~current_count:count then
        Error
          (Domain_error.Budget_exhausted
             { window_name = Window_spec.name window })
      else Ok ())
    windows
  |> Result.map (fun _ -> ())

let record_action t ~now = { timestamps = now :: t.timestamps }

let prune t ~now ~budget =
  let windows = Budget_window_set.windows budget in
  let max_duration =
    List.fold_left
      (fun acc w ->
        let d = Window_spec.duration w in
        if Ptime.Span.compare d acc > 0 then d else acc)
      (Ptime.Span.of_int_s 0)
      windows
  in
  let cutoff =
    match Ptime.sub_span now max_duration with
    | Some s -> s
    | None -> Ptime.epoch
  in
  {
    timestamps =
      List.filter (fun ts -> Ptime.is_later ts ~than:cutoff) t.timestamps;
  }

let export_timestamps t = t.timestamps
let import_timestamps ts = { timestamps = ts }
