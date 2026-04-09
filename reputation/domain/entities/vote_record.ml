(** Vote record — local entity within Message aggregate.

    Immutable record of a cast vote. *)

type t = {
  id : Ids.Vote_id.t;
  voter_id : Ids.Member_id.t;
  vote_type : Vote_type.t;
  weight : Vote_weight.t;
  voted_at : Ptime.t;
}
[@@deriving show, eq]

let create ~id ~voter_id ~vote_type ~weight ~voted_at =
  { id; voter_id; vote_type; weight; voted_at }

let id t = t.id
let voter_id t = t.voter_id
let vote_type t = t.vote_type
let weight t = t.weight
let voted_at t = t.voted_at
