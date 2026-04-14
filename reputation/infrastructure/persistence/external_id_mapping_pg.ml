(** PostgreSQL external ID mapping. *)

open Reputation_domain

module Q = struct
  open Caqti_request.Infix
  open Caqti_type

  let find_member =
    t3 string string int64 ->? int64 @@
    "SELECT member_id FROM external_member_mappings WHERE platform = ? AND external_user_id = ? AND community_id = ?"

  let find_chat =
    t2 string string ->? int64 @@
    "SELECT chat_id FROM external_chat_mappings WHERE platform = ? AND external_chat_id = ?"

  let find_message =
    t2 string string ->? int64 @@
    "SELECT message_id FROM external_message_mappings WHERE platform = ? AND external_message_id = ?"

  let save_member =
    t4 string string int64 int64 ->. unit @@
    {|INSERT INTO external_member_mappings (platform, external_user_id, community_id, member_id)
      VALUES (?, ?, ?, ?) ON CONFLICT DO NOTHING|}

  let save_chat =
    t3 string string int64 ->. unit @@
    {|INSERT INTO external_chat_mappings (platform, external_chat_id, chat_id)
      VALUES (?, ?, ?) ON CONFLICT DO NOTHING|}

  let save_message =
    t3 string string int64 ->. unit @@
    {|INSERT INTO external_message_mappings (platform, external_message_id, message_id)
      VALUES (?, ?, ?) ON CONFLICT DO NOTHING|}
end

module Make () : External_id_mapping.S with type uow = Caqti_unit_of_work.t = struct
  type uow = Caqti_unit_of_work.t

  let find_member_id (module C : Caqti_eio.CONNECTION) ext_id community_id =
    match C.find_opt Q.find_member
            (External_ids.External_user_id.platform ext_id,
             External_ids.External_user_id.value ext_id,
             Ids.Community_id.to_int64 community_id) with
    | Ok None -> Ok None
    | Ok (Some mid) -> Ok (Some (Ids.Member_id.of_int64 mid))
    | Error err -> Error (Format.asprintf "%a" Caqti_error.pp err)

  let find_chat_id (module C : Caqti_eio.CONNECTION) ext_id =
    match C.find_opt Q.find_chat
            (External_ids.External_chat_id.platform ext_id,
             External_ids.External_chat_id.value ext_id) with
    | Ok None -> Ok None
    | Ok (Some cid) -> Ok (Some (Ids.Chat_id.of_int64 cid))
    | Error err -> Error (Format.asprintf "%a" Caqti_error.pp err)

  let find_message_id (module C : Caqti_eio.CONNECTION) ext_id =
    match C.find_opt Q.find_message
            (External_ids.External_message_id.platform ext_id,
             External_ids.External_message_id.value ext_id) with
    | Ok None -> Ok None
    | Ok (Some mid) -> Ok (Some (Ids.Message_id.of_int64 mid))
    | Error err -> Error (Format.asprintf "%a" Caqti_error.pp err)

  let save_member_mapping (module C : Caqti_eio.CONNECTION) ext_id member_id community_id =
    match C.exec Q.save_member
            (External_ids.External_user_id.platform ext_id,
             External_ids.External_user_id.value ext_id,
             Ids.Community_id.to_int64 community_id,
             Ids.Member_id.to_int64 member_id) with
    | Ok () -> Ok ()
    | Error err -> Error (Format.asprintf "%a" Caqti_error.pp err)

  let save_chat_mapping (module C : Caqti_eio.CONNECTION) ext_id chat_id =
    match C.exec Q.save_chat
            (External_ids.External_chat_id.platform ext_id,
             External_ids.External_chat_id.value ext_id,
             Ids.Chat_id.to_int64 chat_id) with
    | Ok () -> Ok ()
    | Error err -> Error (Format.asprintf "%a" Caqti_error.pp err)

  let save_message_mapping (module C : Caqti_eio.CONNECTION) ext_id message_id =
    match C.exec Q.save_message
            (External_ids.External_message_id.platform ext_id,
             External_ids.External_message_id.value ext_id,
             Ids.Message_id.to_int64 message_id) with
    | Ok () -> Ok ()
    | Error err -> Error (Format.asprintf "%a" Caqti_error.pp err)
end
