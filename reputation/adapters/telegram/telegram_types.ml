(** Telegram Bot API types — minimal subset needed for reputation bot. *)

type user = {
  id : int;
  is_bot : bool;
  first_name : string;
  last_name : string option;
  username : string option;
}
[@@deriving show, eq]

type chat = {
  id : int;
  chat_type : string;  (** "private", "group", "supergroup", "channel" *)
  title : string option;
}
[@@deriving show, eq]

type message = {
  message_id : int;
  from : user option;
  chat : chat;
  date : int;
  text : string option;
  reply_to_message : message option;
}
[@@deriving show, eq]

type message_reaction = {
  chat : chat;
  message_id : int;
  user : user option;
  new_reaction : reaction_type list;
  old_reaction : reaction_type list;
}
[@@deriving show, eq]

and reaction_type =
  | Emoji of string
  | CustomEmoji of string
[@@deriving show, eq]

type update = {
  update_id : int;
  message : message option;
  message_reaction : message_reaction option;
}
[@@deriving show, eq]

(** Parse a user from JSON. *)
let user_of_yojson (json : Yojson.Safe.t) : user option =
  try
    let open Yojson.Safe.Util in
    Some
      {
        id = json |> member "id" |> to_int;
        is_bot = json |> member "is_bot" |> to_bool;
        first_name = json |> member "first_name" |> to_string;
        last_name = json |> member "last_name" |> to_string_option;
        username = json |> member "username" |> to_string_option;
      }
  with _ -> None

let chat_of_yojson (json : Yojson.Safe.t) : chat option =
  try
    let open Yojson.Safe.Util in
    Some
      {
        id = json |> member "id" |> to_int;
        chat_type = json |> member "type" |> to_string;
        title = json |> member "title" |> to_string_option;
      }
  with _ -> None

let rec message_of_yojson (json : Yojson.Safe.t) : message option =
  try
    let open Yojson.Safe.Util in
    Some
      {
        message_id = json |> member "message_id" |> to_int;
        from =
          (try json |> member "from" |> user_of_yojson with _ -> None);
        chat =
          (json |> member "chat" |> chat_of_yojson |> Option.get);
        date = json |> member "date" |> to_int;
        text = json |> member "text" |> to_string_option;
        reply_to_message =
          (try
             json |> member "reply_to_message" |> message_of_yojson
           with _ -> None);
      }
  with _ -> None

let reaction_type_of_yojson (json : Yojson.Safe.t) : reaction_type option =
  try
    let open Yojson.Safe.Util in
    let rtype = json |> member "type" |> to_string in
    match rtype with
    | "emoji" -> Some (Emoji (json |> member "emoji" |> to_string))
    | "custom_emoji" ->
        Some (CustomEmoji (json |> member "custom_emoji_id" |> to_string))
    | _ -> None
  with _ -> None

let message_reaction_of_yojson (json : Yojson.Safe.t) : message_reaction option
    =
  try
    let open Yojson.Safe.Util in
    Some
      {
        chat = json |> member "chat" |> chat_of_yojson |> Option.get;
        message_id = json |> member "message_id" |> to_int;
        user =
          (try json |> member "user" |> user_of_yojson with _ -> None);
        new_reaction =
          json |> member "new_reaction" |> to_list
          |> List.filter_map reaction_type_of_yojson;
        old_reaction =
          json |> member "old_reaction" |> to_list
          |> List.filter_map reaction_type_of_yojson;
      }
  with _ -> None

let update_of_yojson (json : Yojson.Safe.t) : update option =
  try
    let open Yojson.Safe.Util in
    Some
      {
        update_id = json |> member "update_id" |> to_int;
        message =
          (try json |> member "message" |> message_of_yojson
           with _ -> None);
        message_reaction =
          (try
             json |> member "message_reaction"
             |> message_reaction_of_yojson
           with _ -> None);
      }
  with _ -> None
