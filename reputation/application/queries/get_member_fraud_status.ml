(** Query: get fraud status for a member. *)

open Reputation_domain
open Ascetic_ddd.Result_ext

type t = {
  member_id : Ids.Member_id.t;
}

type result = {
  member_id : Ids.Member_id.t;
  fraud_score : Fraud_score.t;
  classification : Fraud_score.classification;
  factors : Fraud_factors.t;
  taint_factor : Taint_factor.t;
  is_blocked : bool;
}

let handle (type uow) (deps : uow Deps.t) (uow : uow) (cmd : t) =
  let* member = Cast_vote.load_member deps uow cmd.member_id in
  let fs = Member.fraud_score member in
  let tf = Taint_factor.of_fraud_score fs in
  Ok
    {
      member_id = cmd.member_id;
      fraud_score = fs;
      classification = Fraud_score.classify fs;
      factors = Member.fraud_factors member;
      taint_factor = tf;
      is_blocked = Taint_factor.is_blocked tf;
    }
