(** Telegram update handler — maps updates to application commands.

    Bridges the Telegram adapter to the application layer by:
    1. Parsing triggers from messages/reactions
    2. Resolving external IDs to domain IDs
    3. Dispatching appropriate commands
    4. Formatting and sending response messages *)

open Reputation_domain

let platform = "telegram"

let ext_user_id user_id =
  External_ids.External_user_id.create ~platform
    ~value:(string_of_int user_id)

let ext_chat_id chat_id =
  External_ids.External_chat_id.create ~platform
    ~value:(string_of_int chat_id)

let ext_message_id msg_id chat_id =
  External_ids.External_message_id.create ~platform
    ~value:(Printf.sprintf "%d:%d" chat_id msg_id)

let format_karma_response ~author_name ~delta ~new_karma =
  let direction = if Karma.is_positive delta then "+" else "" in
  Printf.sprintf "%s: %s%s (total: %s)" author_name direction
    (Karma.to_string delta) (Karma.to_string new_karma)

let handle_vote_trigger (type uow) (deps : uow Reputation_app.Deps.t)
    (uow : uow) ~(trigger : Trigger_parser.parsed_trigger) =
  match trigger with
  | Trigger_parser.VoteTrigger
      { vote_type; voter_user_id; author_user_id; message_id; chat_id } ->
      let ext_chat = ext_chat_id chat_id in
      let ext_voter = ext_user_id voter_user_id in
      let ext_author = ext_user_id author_user_id in
      let ext_msg = ext_message_id message_id chat_id in
      (* Resolve chat -> community *)
      let (module ChatRepo) = deps.chat_repo in
      let open Ascetic_ddd.Result_ext in
      let* chat_opt =
        ChatRepo.find_by_external_id uow ext_chat
        |> map_error (fun e -> Domain_error.Invalid_argument e)
      in
      let* chat =
        of_option
          ~error:(Domain_error.Chat_not_found { chat_id = Ids.Chat_id.of_int 0 })
          chat_opt
      in
      let community_id = Chat.community_id chat in
      (* Register both users *)
      let* _voter_reg =
        Reputation_app.Register_member.handle deps uow
          { external_user_id = ext_voter; community_id }
      in
      let* author_reg =
        Reputation_app.Register_member.handle deps uow
          { external_user_id = ext_author; community_id }
      in
      (* Ensure message exists *)
      let* _msg_reg =
        Reputation_app.Record_message.handle deps uow
          {
            external_message_id = ext_msg;
            author_member_id = author_reg.member_id;
            chat_id = Chat.id chat;
          }
      in
      (* Cast vote via the application service *)
      let* vote_result =
        Reputation_app.Vote_application_service.handle_vote deps uow
          {
            external_user_id = ext_voter;
            external_message_id = ext_msg;
            external_chat_id = ext_chat;
            vote_type;
          }
      in
      Ok
        (Some
           {|vote_result|}
           (* In production: format_karma_response with actual names *))
      |> Result.map (fun msg ->
           ignore vote_result;
           msg)
  | _ -> Ok None

let handle_update (type uow) (deps : uow Reputation_app.Deps.t) (uow : uow)
    ~trigger_config (update : Telegram_types.update) =
  match update.message with
  | Some msg ->
      let trigger = Trigger_parser.parse_message_trigger ~trigger_config msg in
      (match trigger with
      | Trigger_parser.NotATrigger -> Ok None
      | _ -> handle_vote_trigger deps uow ~trigger)
  | None -> Ok None
