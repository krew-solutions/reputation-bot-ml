(** Update a member's fraud score from detection results. *)

open Reputation_domain
open Ascetic_ddd.Result_ext

type t = {
  member_id : Ids.Member_id.t;
  community_id : Ids.Community_id.t;
}

let handle (type uow) (deps : uow Deps.t) (uow : uow) (cmd : t) =
  let (module FraudDetection) = deps.fraud_detection in
  let (module EventStore) = deps.event_store in
  let (module Clock) = deps.clock in
  let now = Clock.now () in
  let* factors =
    FraudDetection.calculate_fraud_factors uow cmd.member_id cmd.community_id
    |> map_error (fun e -> Domain_error.Invalid_argument e)
  in
  let* member = Cast_vote.load_member deps uow cmd.member_id in
  let member_version = Member.version member in
  let member = Member.update_fraud_score member ~factors ~now in
  let events = Member.uncommitted_events member in
  if List.length events = 0 then Ok ()  (* Score unchanged *)
  else
    EventStore.append uow
      ~aggregate_id:(Ids.Member_id.show cmd.member_id)
      ~expected_version:member_version events
