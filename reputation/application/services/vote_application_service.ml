(** Vote application service — orchestrates the full vote flow
    from external IDs to domain commands. *)

open Reputation_domain
open Ascetic_ddd.Result_ext

type vote_request = {
  external_user_id : External_ids.External_user_id.t;
  external_message_id : External_ids.External_message_id.t;
  external_chat_id : External_ids.External_chat_id.t;
  vote_type : Vote_type.t;
}

type vote_result = {
  karma_delta : Karma.t;
  new_author_public_karma : Karma.t;
  author_member_id : Ids.Member_id.t;
}

let handle_vote (type uow) (deps : uow Deps.t) (uow : uow)
    (req : vote_request) =
  let (module ChatRepo) = deps.chat_repo in
  let (module IdMapping) = deps.id_mapping in
  (* Resolve chat -> community *)
  let* chat_opt =
    ChatRepo.find_by_external_id uow req.external_chat_id
    |> map_error (fun e -> Domain_error.Invalid_argument e)
  in
  let* chat =
    of_option
      ~error:
        (Domain_error.Chat_not_found
           { chat_id = Ids.Chat_id.of_int 0 })
      chat_opt
  in
  let community_id = Chat.community_id chat in
  (* Ensure voter is registered *)
  let* reg_result =
    Register_member.handle deps uow
      {
        external_user_id = req.external_user_id;
        community_id;
      }
  in
  let voter_id = reg_result.member_id in
  (* Ensure original message author is registered — we need the message *)
  let* message_id_opt =
    IdMapping.find_message_id uow req.external_message_id
    |> map_error (fun e -> Domain_error.Invalid_argument e)
  in
  let* message_id =
    of_option
      ~error:
        (Domain_error.Message_not_found
           { message_id = Ids.Message_id.of_int 0 })
      message_id_opt
  in
  (* Cast the vote *)
  let* result =
    Cast_vote.handle deps uow
      {
        message_id;
        voter_id;
        vote_type = req.vote_type;
        community_id;
      }
  in
  (* Get author ID from message *)
  let (module MessageRepo) = deps.message_repo in
  let* msg_opt =
    MessageRepo.find_by_id uow message_id
    |> map_error (fun e -> Domain_error.Invalid_argument e)
  in
  let author_member_id =
    match msg_opt with
    | Some msg -> Message.author_id msg
    | None -> Ids.Member_id.of_int 0
  in
  Ok
    {
      karma_delta = result.karma_delta;
      new_author_public_karma = result.new_author_public_karma;
      author_member_id;
    }
