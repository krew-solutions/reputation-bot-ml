(** Query: get a member's karma. *)

open Reputation_domain
open Ascetic_ddd.Result_ext

type t = {
  member_id : Ids.Member_id.t;
}

type result = {
  member_id : Ids.Member_id.t;
  public_karma : Karma.t;
  effective_karma : Karma.t;
  voting_power : Voting_power.t;
}

let handle (type uow) (deps : uow Deps.t) (uow : uow) (cmd : t) =
  let (module CommunityRepo) = deps.community_repo in
  let* member = Cast_vote.load_member deps uow cmd.member_id in
  (* Try to load community for thresholds; fall back to defaults *)
  let community_id = Member.community_id member in
  let* community_opt =
    CommunityRepo.find_by_id uow community_id
    |> map_error (fun e -> Domain_error.Invalid_argument e)
  in
  let thresholds =
    match community_opt with
    | Some c ->
        Group_settings.voting_power_thresholds (Community.settings c)
    | None -> Voting_power_thresholds.default
  in
  let dk = Member.dual_karma member in
  Ok
    {
      member_id = cmd.member_id;
      public_karma = Dual_karma.public dk;
      effective_karma = Dual_karma.effective dk;
      voting_power = Member.effective_voting_power member ~thresholds;
    }
