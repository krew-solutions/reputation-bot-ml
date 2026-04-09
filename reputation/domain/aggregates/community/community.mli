(** Community aggregate — groups multiple chats, holds settings.

    State-based with event outbox. *)

type t

val create :
  id:Ids.Community_id.t ->
  name:string ->
  settings:Group_settings.t ->
  now:Ptime.t ->
  t

val id : t -> Ids.Community_id.t
val name : t -> string
val version : t -> int
val settings : t -> Group_settings.t
val chat_ids : t -> Ids.Chat_id.t list

val attach_chat :
  t ->
  chat_id:Ids.Chat_id.t ->
  now:Ptime.t ->
  (t, Domain_error.t) result

val update_settings : t -> settings:Group_settings.t -> t

val uncommitted_events : t -> Domain_events.t Ascetic_ddd.Domain_event.t list
val clear_uncommitted_events : t -> t
