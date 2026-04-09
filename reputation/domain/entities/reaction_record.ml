(** Reaction record — local entity within Message aggregate.

    Immutable record of an emoji reaction. *)

type t = {
  id : Ids.Reaction_id.t;
  reactor_id : Ids.Member_id.t;
  reaction_type : Reaction_type.t;
  weight : Reaction_weight.t;
  reacted_at : Ptime.t;
}
[@@deriving show, eq]

let create ~id ~reactor_id ~reaction_type ~weight ~reacted_at =
  { id; reactor_id; reaction_type; weight; reacted_at }

let id t = t.id
let reactor_id t = t.reactor_id
let reaction_type t = t.reaction_type
let weight t = t.weight
let reacted_at t = t.reacted_at
