(** Message aggregate — state-based with event outbox.

    Owns Vote and Reaction local entities.
    Enforces: no self-vote, no duplicate vote, voting window. *)

type t

(** {1 Construction} *)

val create :
  id:Ids.Message_id.t ->
  author_id:Ids.Member_id.t ->
  chat_id:Ids.Chat_id.t ->
  created_at:Ptime.t ->
  t

(** {1 Queries} *)

val id : t -> Ids.Message_id.t
val author_id : t -> Ids.Member_id.t
val chat_id : t -> Ids.Chat_id.t
val created_at : t -> Ptime.t
val version : t -> int
val votes : t -> Vote_record.t list
val reactions : t -> Reaction_record.t list
val score : t -> Score.t

val has_voted : t -> voter_id:Ids.Member_id.t -> bool
val has_reacted : t -> reactor_id:Ids.Member_id.t -> emoji:string -> bool

(** {1 Commands} *)

val add_vote :
  t ->
  vote_id:Ids.Vote_id.t ->
  voter_id:Ids.Member_id.t ->
  vote_type:Vote_type.t ->
  weight:Vote_weight.t ->
  now:Ptime.t ->
  voting_window:Voting_window.t ->
  (t, Domain_error.t) result
(** Add a vote. Checks self-vote, duplicate, voting window. *)

val add_reaction :
  t ->
  reaction_id:Ids.Reaction_id.t ->
  reactor_id:Ids.Member_id.t ->
  reaction_type:Reaction_type.t ->
  weight:Reaction_weight.t ->
  now:Ptime.t ->
  voting_window:Voting_window.t ->
  (t, Domain_error.t) result
(** Add a reaction. Checks self-reaction, duplicate, voting window. *)

val remove_reaction :
  t ->
  reactor_id:Ids.Member_id.t ->
  emoji:string ->
  (t, Domain_error.t) result
(** Remove a reaction by reactor and emoji. *)

(** {1 Event outbox} *)

val uncommitted_events : t -> Domain_events.t Ascetic_ddd.Domain_event.t list
val clear_uncommitted_events : t -> t
