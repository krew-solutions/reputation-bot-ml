(** Reputation Domain — core business logic.

    With (include_subdirs unqualified), all modules from subdirectories
    are available at the top level. This entrypoint re-exports them
    for external consumers. *)

module Ids = Ids

(* Value Objects *)
module Karma = Karma
module Dual_karma = Dual_karma
module Vote_type = Vote_type
module Voting_power = Voting_power
module Voting_power_thresholds = Voting_power_thresholds
module Vote_weight = Vote_weight
module Reaction_type = Reaction_type
module Reaction_weight = Reaction_weight
module Reaction_percentile = Reaction_percentile
module Score = Score
module Fraud_score = Fraud_score
module Fraud_factors = Fraud_factors
module Taint_factor = Taint_factor
module External_ids = External_ids
module Voting_window = Voting_window
module Window_spec = Window_spec
module Budget_window_set = Budget_window_set
module Group_settings = Group_settings
module Trigger_config = Trigger_config

(* Entities *)
module Vote_record = Vote_record
module Reaction_record = Reaction_record

(* Aggregates *)
module Member = Member
module Sliding_window_budget = Sliding_window_budget
module Voting_power_penalty = Voting_power_penalty
module Message = Message
module Community = Community
module Chat = Chat

(* Events & Errors *)
module Domain_events = Domain_events
module Domain_error = Domain_error

(* Ports *)
module Member_repository = Member_repository
module Message_repository = Message_repository
module Community_repository = Community_repository
module Chat_repository = Chat_repository
module External_id_mapping = External_id_mapping
module Event_publisher = Event_publisher
module Event_store = Event_store
module Fraud_detection_port = Fraud_detection_port
module Reputation_percentile_port = Reputation_percentile_port

(* Domain Services *)
module Karma_calculation = Karma_calculation
module Fraud_scoring = Fraud_scoring
