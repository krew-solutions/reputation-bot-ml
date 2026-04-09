(** Member aggregate — Event Sourced, fraud-aware. *)

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

type t = {
  id : Ids.Member_id.t;
  community_id : Ids.Community_id.t;
  version : int;
  dual_karma : Dual_karma.t;
  fraud_score : Fraud_score.t;
  fraud_factors : Fraud_factors.t;
  budget : Sliding_window_budget.t;
  uncommitted_events : event Ascetic_ddd.Domain_event.t list;
}

(* Internal helpers *)

let emit t ~now event =
  let version = t.version + 1 in
  let envelope =
    Ascetic_ddd.Domain_event.create
      ~aggregate_id:(Ids.Member_id.show t.id)
      ~aggregate_version:version ~occurred_at:now event
  in
  { t with
    version;
    uncommitted_events = t.uncommitted_events @ [ envelope ];
  }

(* Event application — pure state transitions *)

let apply_event_data t event =
  match event with
  | Registered _ -> t  (* State already set at construction *)
  | KarmaReceived { delta; taint_factor; _ } ->
      let dual_karma =
        Dual_karma.receive t.dual_karma ~delta ~taint_factor
      in
      { t with dual_karma }
  | VoteRecorded { voted_at } ->
      let budget = Sliding_window_budget.record_action t.budget ~now:voted_at in
      { t with budget }
  | FraudScoreChanged { new_score; factors; _ } ->
      { t with fraud_score = new_score; fraud_factors = factors }
  | CorrectionApplied { effective_delta; _ } ->
      let dual_karma =
        Dual_karma.apply_correction t.dual_karma ~effective_delta
      in
      { t with dual_karma }

(** [apply_event] for reconstitution — also increments version. *)
let apply_event t event =
  let t = apply_event_data t event in
  { t with version = t.version + 1 }

(* Construction *)

let initial_state ~id ~community_id =
  {
    id;
    community_id;
    version = 0;
    dual_karma = Dual_karma.initial;
    fraud_score = Fraud_score.zero;
    fraud_factors = Fraud_factors.zero;
    budget = Sliding_window_budget.empty;
    uncommitted_events = [];
  }

let register ~id ~community_id ~now =
  let t = initial_state ~id ~community_id in
  let event = Registered { member_id = id; community_id } in
  let t = emit t ~now event in
  apply_event_data t event

(* Queries *)

let id t = t.id
let community_id t = t.community_id
let version t = t.version
let dual_karma t = t.dual_karma
let fraud_score t = t.fraud_score
let fraud_factors t = t.fraud_factors
let budget t = t.budget
let uncommitted_events t = t.uncommitted_events
let clear_uncommitted_events t = { t with uncommitted_events = [] }

let effective_voting_power t ~thresholds =
  let effective_karma = Dual_karma.effective t.dual_karma in
  let base_power =
    Voting_power_thresholds.derive_power thresholds ~effective_karma
  in
  let penalty = Voting_power_penalty.of_fraud_score t.fraud_score in
  Voting_power_penalty.apply penalty base_power

let can_vote t ~now ~budget_windows =
  let open Ascetic_ddd.Result_ext in
  let* () =
    guard
      (not (Voting_power_penalty.is_blocked
              (Voting_power_penalty.of_fraud_score t.fraud_score)))
      ~error:Domain_error.Fraud_blocked
  in
  Sliding_window_budget.check t.budget ~now ~budget:budget_windows

(* Commands *)

let receive_karma t ~delta ~taint_factor ~source_member_id ~reason ~now =
  let event = KarmaReceived { delta; taint_factor; source_member_id; reason } in
  let t = emit t ~now event in
  apply_event_data t event

let record_vote t ~now =
  let event = VoteRecorded { voted_at = now } in
  let t = emit t ~now event in
  apply_event_data t event

let update_fraud_score t ~factors ~now =
  let new_score = Fraud_factors.to_fraud_score factors in
  if Fraud_score.equal t.fraud_score new_score then t
  else
    let event =
      FraudScoreChanged
        { old_score = t.fraud_score; new_score; factors }
    in
    let t = emit t ~now event in
    apply_event_data t event

let apply_correction t ~effective_delta ~reason ~now =
  let event = CorrectionApplied { effective_delta; reason } in
  let t = emit t ~now event in
  apply_event_data t event
