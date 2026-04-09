(** Query: get leaderboard — top-N members by effective karma.

    Note: This is a simplified version. In production, this would
    be backed by a read model/projection for efficiency. *)

open Reputation_domain

type t = {
  community_id : Ids.Community_id.t;
  limit : int;
}

type entry = {
  member_id : Ids.Member_id.t;
  public_karma : Karma.t;
  effective_karma : Karma.t;
}

type result = { entries : entry list }

(** Placeholder — actual implementation requires a read model query port.
    For now, returns empty. Infrastructure layer will provide the real impl. *)
let handle (_type : unit) (_uow : unit) (_cmd : t) =
  Ok { entries = [] }
