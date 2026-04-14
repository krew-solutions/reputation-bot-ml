(** Chat aggregate. *)

type t = {
  id : Ids.Chat_id.t;
  community_id : Ids.Community_id.t;
  version : int;
}

let create ~id ~community_id =
  { id; community_id; version = 1 }

let id t = t.id
let community_id t = t.community_id
let version t = t.version
