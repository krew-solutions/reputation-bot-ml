(** Message aggregate — state-based with event outbox. *)

type t = {
  id : Ids.Message_id.t;
  author_id : Ids.Member_id.t;
  chat_id : Ids.Chat_id.t;
  created_at : Ptime.t;
  version : int;
  votes : Vote_record.t list;
  reactions : Reaction_record.t list;
  score : Score.t;
  uncommitted_events : Domain_events.t Ascetic_ddd.Domain_event.t list;
}

let create ~id ~author_id ~chat_id ~created_at =
  {
    id;
    author_id;
    chat_id;
    created_at;
    version = 0;
    votes = [];
    reactions = [];
    score = Score.zero;
    uncommitted_events = [];
  }

(* Queries *)

let id t = t.id
let author_id t = t.author_id
let chat_id t = t.chat_id
let created_at t = t.created_at
let version t = t.version
let votes t = t.votes
let reactions t = t.reactions
let score t = t.score
let uncommitted_events t = t.uncommitted_events
let clear_uncommitted_events t = { t with uncommitted_events = [] }

let has_voted t ~voter_id =
  List.exists
    (fun v -> Ids.Member_id.equal (Vote_record.voter_id v) voter_id)
    t.votes

let has_reacted t ~reactor_id ~emoji =
  List.exists
    (fun r ->
      Ids.Member_id.equal (Reaction_record.reactor_id r) reactor_id
      && String.equal (Reaction_type.emoji (Reaction_record.reaction_type r)) emoji)
    t.reactions

(* Internal *)

let emit t ~now event =
  let version = t.version + 1 in
  let envelope =
    Ascetic_ddd.Domain_event.create
      ~aggregate_id:(Ids.Message_id.show t.id)
      ~aggregate_version:version ~occurred_at:now event
  in
  { t with
    version;
    uncommitted_events = t.uncommitted_events @ [ envelope ];
  }

(* Commands *)

let add_vote t ~vote_id ~voter_id ~vote_type ~weight ~now ~voting_window =
  let open Ascetic_ddd.Result_ext in
  let* () =
    guard
      (not (Ids.Member_id.equal voter_id t.author_id))
      ~error:Domain_error.Self_vote_prohibited
  in
  let* () =
    guard (not (has_voted t ~voter_id))
      ~error:Domain_error.Duplicate_vote
  in
  let* () =
    guard
      (Voting_window.is_open voting_window ~message_created_at:t.created_at ~now)
      ~error:Domain_error.Voting_window_closed
  in
  let vote =
    Vote_record.create ~id:vote_id ~voter_id ~vote_type ~weight ~voted_at:now
  in
  let new_score = Score.add_vote_weight t.score weight in
  let event : Domain_events.t =
    VoteCast
      {
        message_id = t.id;
        voter_id;
        author_id = t.author_id;
        vote_type;
        weight;
      }
  in
  let t =
    { t with votes = t.votes @ [ vote ]; score = new_score }
  in
  Ok (emit t ~now event)

let add_reaction t ~reaction_id ~reactor_id ~reaction_type ~weight ~now
    ~voting_window =
  let open Ascetic_ddd.Result_ext in
  let emoji = Reaction_type.emoji reaction_type in
  let* () =
    guard
      (not (Ids.Member_id.equal reactor_id t.author_id))
      ~error:Domain_error.Self_vote_prohibited
  in
  let* () =
    guard
      (not (has_reacted t ~reactor_id ~emoji))
      ~error:Domain_error.Duplicate_reaction
  in
  let* () =
    guard
      (Voting_window.is_open voting_window ~message_created_at:t.created_at ~now)
      ~error:Domain_error.Voting_window_closed
  in
  let reaction =
    Reaction_record.create ~id:reaction_id ~reactor_id ~reaction_type ~weight
      ~reacted_at:now
  in
  let new_score = Score.add_reaction_weight t.score weight in
  let event : Domain_events.t =
    ReactionAdded
      {
        message_id = t.id;
        reactor_id;
        author_id = t.author_id;
        reaction_type;
        weight;
      }
  in
  let t =
    { t with reactions = t.reactions @ [ reaction ]; score = new_score }
  in
  Ok (emit t ~now event)

let remove_reaction t ~reactor_id ~emoji =
  let open Ascetic_ddd.Result_ext in
  let* () =
    guard
      (has_reacted t ~reactor_id ~emoji)
      ~error:Domain_error.Reaction_not_found
  in
  let removed_reaction =
    List.find
      (fun r ->
        Ids.Member_id.equal (Reaction_record.reactor_id r) reactor_id
        && String.equal (Reaction_type.emoji (Reaction_record.reaction_type r)) emoji)
      t.reactions
  in
  let remaining =
    List.filter (fun r -> not (Reaction_record.equal r removed_reaction)) t.reactions
  in
  let event : Domain_events.t =
    ReactionRemoved
      {
        message_id = t.id;
        reactor_id;
        reaction_type = Reaction_record.reaction_type removed_reaction;
      }
  in
  let now = Reaction_record.reacted_at removed_reaction in
  Ok (emit { t with reactions = remaining; version = t.version } ~now event)
