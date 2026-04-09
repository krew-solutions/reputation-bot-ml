(** PostgreSQL community repository. *)

open Reputation_domain

module Q = struct
  open Caqti_request.Infix
  open Caqti_type

  let find_by_id =
    int64 ->? t3 int64 string int @@
    "SELECT id, name, version FROM communities WHERE id = ?"

  let insert =
    t3 int64 string int ->. unit @@
    "INSERT INTO communities (id, name, version) VALUES (?, ?, ?)"

  let update_version =
    t3 int int64 int ->. unit @@
    "UPDATE communities SET version = ?, updated_at = NOW() WHERE id = ? AND version = ?"

  let next_id =
    unit ->! int64 @@ "SELECT nextval('communities_id_seq')"
end

module Make () : Community_repository.S with type uow = Caqti_unit_of_work.t = struct
  type uow = Caqti_unit_of_work.t

  let find_by_id (module C : Caqti_eio.CONNECTION) id =
    match C.find_opt Q.find_by_id (Ids.Community_id.to_int64 id) with
    | Ok None -> Ok None
    | Ok (Some (id_raw, name, _version)) ->
        Ok (Some (Community.clear_uncommitted_events
                    (Community.create
                       ~id:(Ids.Community_id.of_int64 id_raw)
                       ~name ~settings:Group_settings.default
                       ~now:Ptime.epoch)))
    | Error err -> Error (Format.asprintf "%a" Caqti_error.pp err)

  let save (module C : Caqti_eio.CONNECTION) community ~expected_version =
    let id = Ids.Community_id.to_int64 (Community.id community) in
    if expected_version = 0 then
      match C.exec Q.insert (id, Community.name community, Community.version community) with
      | Ok () -> Ok ()
      | Error err -> Error (Domain_error.Invalid_argument (Format.asprintf "%a" Caqti_error.pp err))
    else
      match C.exec Q.update_version (Community.version community, id, expected_version) with
      | Ok () -> Ok ()
      | Error err -> Error (Domain_error.Invalid_argument (Format.asprintf "%a" Caqti_error.pp err))

  let next_id (module C : Caqti_eio.CONNECTION) =
    match C.find Q.next_id () with
    | Ok id -> Ok (Ids.Community_id.of_int64 id)
    | Error err -> Error (Format.asprintf "%a" Caqti_error.pp err)
end
