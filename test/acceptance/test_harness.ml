(** In-process component test harness.

    Wires together real domain + application layers with in-memory
    infrastructure. Provides helper functions for common operations. *)

open Reputation_domain
open Test_support

type ctx = {
  deps : unit Reputation_app.Deps.t;
  community_id : Ids.Community_id.t option;
  chat_id : Ids.Chat_id.t option;
  members : (string * Ids.Member_id.t) list;  (* name -> member_id *)
  messages : (string * Ids.Message_id.t) list; (* label -> message_id *)
  last_error : Domain_error.t option;
  last_karma_delta : Karma.t option;
}

let fresh_ctx () =
  In_memory_repos.clear_all ();
  {
    deps = In_memory_repos.make_deps ();
    community_id = None;
    chat_id = None;
    members = [];
    messages = [];
    last_error = None;
    last_karma_delta = None;
  }

let create_community ctx ~name =
  let result =
    Reputation_app.Create_community.handle ctx.deps ()
      { name; settings = None }
  in
  match result with
  | Ok r -> { ctx with community_id = Some r.community_id }
  | Error e -> Alcotest.fail (Domain_error.show e)

let create_community_with_settings ctx ~name ~settings =
  let result =
    Reputation_app.Create_community.handle ctx.deps ()
      { name; settings = Some settings }
  in
  match result with
  | Ok r -> { ctx with community_id = Some r.community_id }
  | Error e -> Alcotest.fail (Domain_error.show e)

let attach_chat ctx =
  let community_id = Option.get ctx.community_id in
  let ext_chat =
    External_ids.External_chat_id.create ~platform:"test"
      ~value:"chat1"
  in
  let result =
    Reputation_app.Attach_chat.handle ctx.deps ()
      { community_id; external_chat_id = ext_chat }
  in
  match result with
  | Ok r -> { ctx with chat_id = Some r.chat_id }
  | Error e -> Alcotest.fail (Domain_error.show e)

let register_member ctx ~name =
  let community_id = Option.get ctx.community_id in
  let ext_user =
    External_ids.External_user_id.create ~platform:"test" ~value:name
  in
  let result =
    Reputation_app.Register_member.handle ctx.deps ()
      { external_user_id = ext_user; community_id }
  in
  match result with
  | Ok r ->
      { ctx with members = (name, r.member_id) :: ctx.members }
  | Error e -> Alcotest.fail (Domain_error.show e)

let post_message ctx ~author_name ~label =
  let author_id = List.assoc author_name ctx.members in
  let chat_id = Option.get ctx.chat_id in
  let ext_msg =
    External_ids.External_message_id.create ~platform:"test" ~value:label
  in
  let result =
    Reputation_app.Record_message.handle ctx.deps ()
      {
        external_message_id = ext_msg;
        author_member_id = author_id;
        chat_id;
      }
  in
  match result with
  | Ok r ->
      { ctx with messages = (label, r.message_id) :: ctx.messages }
  | Error e -> Alcotest.fail (Domain_error.show e)

let cast_vote ctx ~voter_name ~message_label ~vote_type =
  let voter_id = List.assoc voter_name ctx.members in
  let message_id = List.assoc message_label ctx.messages in
  let community_id = Option.get ctx.community_id in
  let result =
    Reputation_app.Cast_vote.handle ctx.deps ()
      { message_id; voter_id; vote_type; community_id }
  in
  match result with
  | Ok r ->
      { ctx with
        last_error = None;
        last_karma_delta = Some r.karma_delta;
      }
  | Error e -> { ctx with last_error = Some e; last_karma_delta = None }

let get_member_karma ctx ~name =
  let member_id = List.assoc name ctx.members in
  match
    Reputation_app.Get_member_karma.handle ctx.deps ()
      { member_id }
  with
  | Ok r -> (Karma.to_float r.public_karma, Karma.to_float r.effective_karma)
  | Error e -> Alcotest.fail (Domain_error.show e)
