(** Member aggregate — Event Sourced, fraud-aware.

    The central aggregate of the reputation domain. Holds:
    - DualKarma (public + effective)
    - SlidingWindowBudget
    - FraudScore + FraudFactors
    - Derived VotingPower (with penalty)

    State is reconstructed by folding [apply_event] over the event stream.

    {2 Key Invariants}
    - effective karma <= public karma (via DualKarma)
    - version increments by 1 per event (both emit and apply_event)
    - fraud score in [\[0, 100\]] (via FraudScore)
    - confirmed fraudsters (score >= 80) cannot vote

    {2 Contracts}
    - [register]: version = 1, karma = 0
    - [receive_karma ~taint_factor]: requires [0.0 <= taint_factor <= 1.0],
      version increments, DualKarma invariant preserved
    - [record_vote]: version increments
    - [apply_correction]: only effective karma changes, public unchanged,
      DualKarma invariant preserved
    - [apply_event]: version increments by 1 (for reconstitution) *)

type t

type event =
  | Registered of {
      member_id : Ids.Member_id.t;
      community_id : Ids.Community_id.t;
    }
  | KarmaReceived of {
      delta : Karma.t;
      taint_factor : float;
      source_member_id : Ids.Member_id.t;
      reason : string;
    }
  | VoteRecorded of { voted_at : Ptime.t }
  | FraudScoreChanged of {
      old_score : Fraud_score.t;
      new_score : Fraud_score.t;
      factors : Fraud_factors.t;
    }
  | CorrectionApplied of {
      effective_delta : Karma.t;
      reason : string;
    }
[@@deriving show, eq]

(** {1 Construction} *)

val register :
  id:Ids.Member_id.t ->
  community_id:Ids.Community_id.t ->
  now:Ptime.t ->
  t

(** {1 Queries} *)

val id : t -> Ids.Member_id.t
val community_id : t -> Ids.Community_id.t
val version : t -> int
val dual_karma : t -> Dual_karma.t
val fraud_score : t -> Fraud_score.t
val fraud_factors : t -> Fraud_factors.t
val budget : t -> Sliding_window_budget.t

val effective_voting_power :
  t -> thresholds:Voting_power_thresholds.t -> Voting_power.t

val can_vote :
  t ->
  now:Ptime.t ->
  budget_windows:Budget_window_set.t ->
  (unit, Domain_error.t) result

(** {1 Commands} *)

val receive_karma :
  t ->
  delta:Karma.t ->
  taint_factor:float ->
  source_member_id:Ids.Member_id.t ->
  reason:string ->
  now:Ptime.t ->
  t

val record_vote : t -> now:Ptime.t -> t

val update_fraud_score :
  t -> factors:Fraud_factors.t -> now:Ptime.t -> t

val apply_correction :
  t -> effective_delta:Karma.t -> reason:string -> now:Ptime.t -> t

(** {1 Event Sourcing} *)

val uncommitted_events : t -> event Ascetic_ddd.Domain_event.t list
val clear_uncommitted_events : t -> t
val apply_event : t -> event -> t
val initial_state : id:Ids.Member_id.t -> community_id:Ids.Community_id.t -> t
