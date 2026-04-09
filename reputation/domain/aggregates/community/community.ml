(** Community aggregate. *)

type t = {
  id : Ids.Community_id.t;
  name : string;
  version : int;
  settings : Group_settings.t;
  chat_ids : Ids.Chat_id.t list;
  uncommitted_events : Domain_events.t Ascetic_ddd.Domain_event.t list;
}

let create ~id ~name ~settings ~now =
  let event : Domain_events.t =
    CommunityCreated { community_id = id; name }
  in
  let envelope =
    Ascetic_ddd.Domain_event.create
      ~aggregate_id:(Ids.Community_id.show id)
      ~aggregate_version:1 ~occurred_at:now event
  in
  {
    id;
    name;
    version = 1;
    settings;
    chat_ids = [];
    uncommitted_events = [ envelope ];
  }

let id t = t.id
let name t = t.name
let version t = t.version
let settings t = t.settings
let chat_ids t = t.chat_ids
let uncommitted_events t = t.uncommitted_events
let clear_uncommitted_events t = { t with uncommitted_events = [] }

let attach_chat t ~chat_id ~now =
  let open Ascetic_ddd.Result_ext in
  let* () =
    guard
      (not (List.exists (Ids.Chat_id.equal chat_id) t.chat_ids))
      ~error:Domain_error.Chat_already_attached
  in
  let version = t.version + 1 in
  let event : Domain_events.t =
    ChatAttached { community_id = t.id; chat_id }
  in
  let envelope =
    Ascetic_ddd.Domain_event.create
      ~aggregate_id:(Ids.Community_id.show t.id)
      ~aggregate_version:version ~occurred_at:now event
  in
  Ok
    {
      t with
      version;
      chat_ids = t.chat_ids @ [ chat_id ];
      uncommitted_events = t.uncommitted_events @ [ envelope ];
    }

let update_settings t ~settings = { t with settings }
