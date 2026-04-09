(** PostgreSQL message repository. *)

open Reputation_domain

module Q = struct
  open Caqti_request.Infix
  open Caqti_type

  let find_by_id =
    int64 ->? t4 int64 int64 int64 ptime @@
    "SELECT id, author_id, chat_id, created_at FROM messages WHERE id = ?"

  let insert =
    t5 int64 int64 int64 ptime int ->. unit @@
    "INSERT INTO messages (id, author_id, chat_id, created_at, version) VALUES (?, ?, ?, ?, ?)"

  let update_version =
    t3 int int int64 ->. unit @@
    "UPDATE messages SET version = ?, updated_at = NOW() WHERE id = ? AND version = ?"

  let next_id =
    unit ->! int64 @@ "SELECT nextval('messages_id_seq')"
end

module Make () : Message_repository.S with type uow = Caqti_unit_of_work.t = struct
  type uow = Caqti_unit_of_work.t

  let find_by_id (module C : Caqti_eio.CONNECTION) id =
    match C.find_opt Q.find_by_id (Ids.Message_id.to_int64 id) with
    | Ok None -> Ok None
    | Ok (Some (id_raw, author_raw, chat_raw, created_at)) ->
        Ok (Some (Message.create
                    ~id:(Ids.Message_id.of_int64 id_raw)
                    ~author_id:(Ids.Member_id.of_int64 author_raw)
                    ~chat_id:(Ids.Chat_id.of_int64 chat_raw)
                    ~created_at))
    | Error err -> Error (Format.asprintf "%a" Caqti_error.pp err)

  let save (module C : Caqti_eio.CONNECTION) msg ~expected_version =
    let id = Ids.Message_id.to_int64 (Message.id msg) in
    if expected_version = 0 then
      match C.exec Q.insert
              (id,
               Ids.Member_id.to_int64 (Message.author_id msg),
               Ids.Chat_id.to_int64 (Message.chat_id msg),
               Message.created_at msg,
               Message.version msg) with
      | Ok () -> Ok ()
      | Error err -> Error (Domain_error.Invalid_argument (Format.asprintf "%a" Caqti_error.pp err))
    else
      match C.exec Q.update_version (Message.version msg, expected_version, id) with
      | Ok () -> Ok ()
      | Error err -> Error (Domain_error.Invalid_argument (Format.asprintf "%a" Caqti_error.pp err))

  let next_id (module C : Caqti_eio.CONNECTION) =
    match C.find Q.next_id () with
    | Ok id -> Ok (Ids.Message_id.of_int64 id)
    | Error err -> Error (Format.asprintf "%a" Caqti_error.pp err)
end
