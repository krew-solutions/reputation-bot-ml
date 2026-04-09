(** Domain errors — all business rule violations. *)

type t =
  | Self_vote_prohibited
  | Duplicate_vote
  | Voting_window_closed
  | Budget_exhausted of { window_name : string }
  | Concurrency_conflict of { expected_version : int; actual_version : int }
  | Fraud_blocked
  | Reaction_percentile_not_reached of { required_pct : int; actual_pct : float }
  | Member_not_found of { member_id : Ids.Member_id.t }
  | Message_not_found of { message_id : Ids.Message_id.t }
  | Community_not_found of { community_id : Ids.Community_id.t }
  | Chat_not_found of { chat_id : Ids.Chat_id.t }
  | Chat_already_attached
  | Duplicate_reaction
  | Reaction_not_found
  | Invalid_argument of string
[@@deriving show, eq]

let to_string = show
