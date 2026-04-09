(** Chat aggregate. *)

type t = {
  id : Ids.Chat_id.t;
  community_id : Ids.Community_id.t;
  external_chat_id : External_ids.External_chat_id.t;
  version : int;
}

let create ~id ~community_id ~external_chat_id =
  { id; community_id; external_chat_id; version = 1 }

let id t = t.id
let community_id t = t.community_id
let external_chat_id t = t.external_chat_id
let version t = t.version
