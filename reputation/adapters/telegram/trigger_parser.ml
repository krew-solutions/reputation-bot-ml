(** Trigger parser — extracts vote/reaction intent from Telegram messages.

    Parses the first word of a reply message against the community's
    trigger configuration (words and emojis). *)

open Reputation_domain

type parsed_trigger =
  | VoteTrigger of {
      vote_type : Vote_type.t;
      voter_user_id : int;
      author_user_id : int;
      message_id : int;
      chat_id : int;
    }
  | ReactionTrigger of {
      reaction_type : Reaction_type.t;
      reactor_user_id : int;
      author_user_id : int;
      message_id : int;
      chat_id : int;
    }
  | NotATrigger
[@@deriving show]

let extract_first_token (text : string) : string =
  let trimmed = String.trim text in
  match String.split_on_char ' ' trimmed with
  | [] -> ""
  | first :: _ -> first

let is_emoji_start (s : string) : bool =
  (* Simple heuristic: non-ASCII first byte means likely emoji/unicode *)
  String.length s > 0 && Char.code s.[0] > 127

let parse_message_trigger ~(trigger_config : Trigger_config.t)
    (message : Telegram_types.message) : parsed_trigger =
  match message.reply_to_message, message.from, message.text with
  | Some reply, Some from_user, Some text when not from_user.is_bot ->
      let reply_author_id =
        match reply.from with Some u -> u.id | None -> 0
      in
      if reply_author_id = 0 || reply_author_id = from_user.id then
        NotATrigger  (* No author or self-reply *)
      else
        let first_token = extract_first_token text in
        (* Try word trigger *)
        (match Trigger_config.classify_word first_token trigger_config with
        | Some vote_type ->
            VoteTrigger
              {
                vote_type;
                voter_user_id = from_user.id;
                author_user_id = reply_author_id;
                message_id = reply.message_id;
                chat_id = message.chat.id;
              }
        | None ->
            (* Try emoji trigger *)
            if is_emoji_start first_token then
              match
                Trigger_config.classify_emoji first_token trigger_config
              with
              | Some vote_type ->
                  VoteTrigger
                    {
                      vote_type;
                      voter_user_id = from_user.id;
                      author_user_id = reply_author_id;
                      message_id = reply.message_id;
                      chat_id = message.chat.id;
                    }
              | None -> NotATrigger
            else NotATrigger)
  | _ -> NotATrigger

let parse_reaction_trigger (reaction : Telegram_types.message_reaction) :
    parsed_trigger =
  match reaction.user with
  | None -> NotATrigger
  | Some user when user.is_bot -> NotATrigger
  | Some user ->
      (* Find new emojis that weren't in old_reaction *)
      let new_emojis =
        List.filter_map
          (function
            | Telegram_types.Emoji e ->
                if
                  not
                    (List.exists
                       (function
                         | Telegram_types.Emoji old_e -> String.equal e old_e
                         | _ -> false)
                       reaction.old_reaction)
                then Some e
                else None
            | _ -> None)
          reaction.new_reaction
      in
      (match new_emojis with
      | emoji :: _ ->
          ReactionTrigger
            {
              reaction_type =
                Reaction_type.create ~emoji ~direction:Reaction_type.Positive;
              reactor_user_id = user.id;
              author_user_id = 0;  (* Unknown from reaction — needs lookup *)
              message_id = reaction.message_id;
              chat_id = reaction.chat.id;
            }
      | [] -> NotATrigger)
