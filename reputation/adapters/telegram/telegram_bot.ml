(** Telegram Bot API client using Eio + cohttp. *)

type t = {
  token : string;
  base_url : string;
  client : Cohttp_eio.Client.t;
  sw : Eio.Switch.t;
}

let create ~sw ~client ~token =
  {
    token;
    base_url = Printf.sprintf "https://api.telegram.org/bot%s" token;
    client;
    sw;
  }

let api_url t method_name =
  Printf.sprintf "%s/%s" t.base_url method_name

let call_api t ~method_name ~body =
  let uri = Uri.of_string (api_url t method_name) in
  let headers =
    Cohttp.Header.of_list [ ("Content-Type", "application/json") ]
  in
  let body = Cohttp_eio.Body.of_string body in
  let resp, resp_body =
    Cohttp_eio.Client.post t.client ~sw:t.sw ~headers ~body uri
  in
  let status = Cohttp.Response.status resp in
  let body_str =
    Eio.Buf_read.(of_flow ~max_size:1_000_000 resp_body |> take_all)
  in
  if Cohttp.Code.is_success (Cohttp.Code.code_of_status status) then
    Ok (Yojson.Safe.from_string body_str)
  else
    Error
      (Printf.sprintf "Telegram API error %d: %s"
         (Cohttp.Code.code_of_status status)
         body_str)

let get_updates t ~offset ~timeout =
  let body =
    `Assoc
      [
        ("offset", `Int offset);
        ("timeout", `Int timeout);
        ("allowed_updates",
         `List [ `String "message"; `String "message_reaction" ]);
      ]
    |> Yojson.Safe.to_string
  in
  match call_api t ~method_name:"getUpdates" ~body with
  | Error e -> Error e
  | Ok json -> (
      try
        let open Yojson.Safe.Util in
        let ok = json |> member "ok" |> to_bool in
        if ok then
          let result = json |> member "result" |> to_list in
          Ok (List.filter_map Telegram_types.update_of_yojson result)
        else Error "Telegram API returned ok=false"
      with exn -> Error (Printexc.to_string exn))

let send_message t ~chat_id ~text ~reply_to_message_id =
  let body =
    let base = [ ("chat_id", `Int chat_id); ("text", `String text) ] in
    let with_reply =
      match reply_to_message_id with
      | Some mid -> ("reply_to_message_id", `Int mid) :: base
      | None -> base
    in
    `Assoc with_reply |> Yojson.Safe.to_string
  in
  match call_api t ~method_name:"sendMessage" ~body with
  | Ok _ -> Ok ()
  | Error e -> Error e
