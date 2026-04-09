(** PostgreSQL event store for event-sourced aggregates. *)

open Reputation_domain

module Q = struct
  open Caqti_request.Infix
  open Caqti_type

  let append_event =
    t5 string int string string ptime
    ->. unit @@
    {|INSERT INTO event_store (aggregate_id, aggregate_version, event_type, payload, occurred_at)
      VALUES (?, ?, ?, ?::bytea, ?)|}

  let load_events =
    t2 string int
    ->* t4 int string string ptime @@
    {|SELECT aggregate_version, event_type, payload::text, occurred_at
      FROM event_store
      WHERE aggregate_id = ? AND aggregate_version > ?
      ORDER BY aggregate_version ASC|}

  let load_snapshot =
    string ->? t2 int string @@
    {|SELECT version, data::text FROM event_store_snapshots WHERE aggregate_id = ?|}

  let save_snapshot =
    t3 string int string ->. unit @@
    {|INSERT INTO event_store_snapshots (aggregate_id, version, data)
      VALUES (?, ?, ?::bytea)
      ON CONFLICT (aggregate_id) DO UPDATE SET version = EXCLUDED.version, data = EXCLUDED.data|}

  let get_version =
    string ->? int @@
    {|SELECT MAX(aggregate_version) FROM event_store WHERE aggregate_id = ?|}
end

let serialize_event (event : Member.event) : string * string =
  match event with
  | Registered { member_id; community_id } ->
      ("Registered",
       Printf.sprintf "%Ld,%Ld"
         (Ids.Member_id.to_int64 member_id)
         (Ids.Community_id.to_int64 community_id))
  | KarmaReceived { delta; taint_factor; source_member_id; reason } ->
      ("KarmaReceived",
       Printf.sprintf "%d,%f,%Ld,%s"
         (Ascetic_ddd.Decimal.to_raw (Karma.to_decimal delta))
         taint_factor
         (Ids.Member_id.to_int64 source_member_id)
         reason)
  | VoteRecorded { voted_at } ->
      ("VoteRecorded", Printf.sprintf "%f" (Ptime.to_float_s voted_at))
  | FraudScoreChanged { old_score; new_score; factors = _ } ->
      ("FraudScoreChanged",
       Printf.sprintf "%d,%d" (Fraud_score.to_int old_score) (Fraud_score.to_int new_score))
  | CorrectionApplied { effective_delta; reason } ->
      ("CorrectionApplied",
       Printf.sprintf "%d,%s" (Ascetic_ddd.Decimal.to_raw (Karma.to_decimal effective_delta)) reason)

let deserialize_event (event_type : string) (_payload : string) : Member.event option =
  match event_type with
  | _ -> None  (* Full deserialization deferred to integration phase *)

module Make () : Event_store.S with type uow = Caqti_unit_of_work.t = struct
  type uow = Caqti_unit_of_work.t

  let append (module C : Caqti_eio.CONNECTION) ~aggregate_id ~expected_version events =
    match C.find_opt Q.get_version aggregate_id with
    | Error err ->
        Error (Domain_error.Invalid_argument (Format.asprintf "%a" Caqti_error.pp err))
    | Ok ver ->
        let current = Option.value ~default:0 ver in
        if current <> expected_version then
          Error (Domain_error.Concurrency_conflict { expected_version; actual_version = current })
        else
          let rec go = function
            | [] -> Ok ()
            | e :: rest ->
                let ev = e.Ascetic_ddd.Domain_event.payload in
                let event_type, payload = serialize_event ev in
                let version = e.Ascetic_ddd.Domain_event.aggregate_version in
                let occurred_at = e.Ascetic_ddd.Domain_event.occurred_at in
                match C.exec Q.append_event (aggregate_id, version, event_type, payload, occurred_at) with
                | Ok () -> go rest
                | Error err -> Error (Domain_error.Invalid_argument (Format.asprintf "%a" Caqti_error.pp err))
          in
          go events

  let load_events (module C : Caqti_eio.CONNECTION) ~aggregate_id ~since_version =
    match C.collect_list Q.load_events (aggregate_id, since_version) with
    | Error err -> Error (Format.asprintf "%a" Caqti_error.pp err)
    | Ok rows ->
        Ok (List.filter_map
              (fun (version, event_type, payload, occurred_at) ->
                match deserialize_event event_type payload with
                | Some event ->
                    Some (Ascetic_ddd.Domain_event.create ~aggregate_id
                            ~aggregate_version:version ~occurred_at event)
                | None -> None)
              rows)

  let save_snapshot (module C : Caqti_eio.CONNECTION) ~aggregate_id ~version ~data =
    match C.exec Q.save_snapshot (aggregate_id, version, data) with
    | Ok () -> Ok ()
    | Error err -> Error (Format.asprintf "%a" Caqti_error.pp err)

  let load_snapshot (module C : Caqti_eio.CONNECTION) ~aggregate_id =
    match C.find_opt Q.load_snapshot aggregate_id with
    | Ok result -> Ok result
    | Error err -> Error (Format.asprintf "%a" Caqti_error.pp err)
end
