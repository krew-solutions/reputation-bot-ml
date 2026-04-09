(** Chat aggregate — belongs to a community, holds external chat ID.

    Maps an external chat (Telegram group, Discord channel, etc.)
    to a community. *)

type t

val create :
  id:Ids.Chat_id.t ->
  community_id:Ids.Community_id.t ->
  external_chat_id:External_ids.External_chat_id.t ->
  t

val id : t -> Ids.Chat_id.t
val community_id : t -> Ids.Community_id.t
val external_chat_id : t -> External_ids.External_chat_id.t
val version : t -> int
