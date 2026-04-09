(** Reputation Application — CQRS commands, queries, and services. *)

(* Dependencies *)
module Deps = Deps

(* Commands *)
module Register_member = Register_member
module Record_message = Record_message
module Cast_vote = Cast_vote
module Add_reaction = Add_reaction
module Remove_reaction = Remove_reaction
module Update_fraud_score = Update_fraud_score
module Apply_ring_correction = Apply_ring_correction
module Create_community = Create_community
module Attach_chat = Attach_chat

(* Queries *)
module Get_member_karma = Get_member_karma
module Get_leaderboard = Get_leaderboard
module Get_member_fraud_status = Get_member_fraud_status

(* Services *)
module Vote_application_service = Vote_application_service
module Fraud_application_service = Fraud_application_service
