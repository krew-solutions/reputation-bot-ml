(** Domain events — all events emitted by aggregates. *)

type member_registered = {
  member_id : Ids.Member_id.t;
  community_id : Ids.Community_id.t;
}
[@@deriving show, eq]

type vote_cast = {
  message_id : Ids.Message_id.t;
  voter_id : Ids.Member_id.t;
  author_id : Ids.Member_id.t;
  vote_type : Vote_type.t;
  weight : Vote_weight.t;
}
[@@deriving show, eq]

type karma_awarded = {
  member_id : Ids.Member_id.t;
  delta : Karma.t;
  reason : string;
  source_member_id : Ids.Member_id.t;
  taint_factor : float;
}
[@@deriving show, eq]

type karma_deducted = {
  member_id : Ids.Member_id.t;
  delta : Karma.t;
  reason : string;
  source_member_id : Ids.Member_id.t;
  taint_factor : float;
}
[@@deriving show, eq]

type reaction_added = {
  message_id : Ids.Message_id.t;
  reactor_id : Ids.Member_id.t;
  author_id : Ids.Member_id.t;
  reaction_type : Reaction_type.t;
  weight : Reaction_weight.t;
}
[@@deriving show, eq]

type reaction_removed = {
  message_id : Ids.Message_id.t;
  reactor_id : Ids.Member_id.t;
  reaction_type : Reaction_type.t;
}
[@@deriving show, eq]

type fraud_score_updated = {
  member_id : Ids.Member_id.t;
  old_score : Fraud_score.t;
  new_score : Fraud_score.t;
  factors : Fraud_factors.t;
}
[@@deriving show, eq]

type fraud_threshold_crossed = {
  member_id : Ids.Member_id.t;
  old_classification : Fraud_score.classification;
  new_classification : Fraud_score.classification;
}
[@@deriving show, eq]

type voting_power_penalized = {
  member_id : Ids.Member_id.t;
  old_multiplier : float;
  new_multiplier : float;
}
[@@deriving show, eq]

type voting_ring_detected = {
  ring_member_ids : Ids.Member_id.t list;
  total_fraudulent_karma : Karma.t;
}
[@@deriving show, eq]

type karma_correction_applied = {
  member_id : Ids.Member_id.t;
  effective_delta : Karma.t;
  reason : string;
}
[@@deriving show, eq]

type community_created = {
  community_id : Ids.Community_id.t;
  name : string;
}
[@@deriving show, eq]

type chat_attached = {
  community_id : Ids.Community_id.t;
  chat_id : Ids.Chat_id.t;
}
[@@deriving show, eq]

(** Sum type of all domain events. *)
type t =
  | MemberRegistered of member_registered
  | VoteCast of vote_cast
  | KarmaAwarded of karma_awarded
  | KarmaDeducted of karma_deducted
  | ReactionAdded of reaction_added
  | ReactionRemoved of reaction_removed
  | FraudScoreUpdated of fraud_score_updated
  | FraudThresholdCrossed of fraud_threshold_crossed
  | VotingPowerPenalized of voting_power_penalized
  | VotingRingDetected of voting_ring_detected
  | KarmaCorrectionApplied of karma_correction_applied
  | CommunityCreated of community_created
  | ChatAttached of chat_attached
[@@deriving show, eq]
