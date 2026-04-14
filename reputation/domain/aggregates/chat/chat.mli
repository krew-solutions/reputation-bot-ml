(** Chat aggregate — belongs to a community.

    Maps to an external chat (Telegram group, Discord channel, etc.)
    via the External ID mapping infrastructure port.
    The chat itself does not know about platform details. *)

type t

val create :
  id:Ids.Chat_id.t ->
  community_id:Ids.Community_id.t ->
  t

val id : t -> Ids.Chat_id.t
val community_id : t -> Ids.Community_id.t
val version : t -> int
