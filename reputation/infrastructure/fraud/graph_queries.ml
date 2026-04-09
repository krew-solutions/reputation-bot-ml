(** Individual Caqti queries for graph-based fraud analysis.

    These can be used independently of the materialized views
    for real-time analysis. *)

open Reputation_domain

module Q = struct
  open Caqti_request.Infix
  open Caqti_type

  let reciprocal_pairs =
    t2 int64 float
    ->* t3 int64 int64 float @@
    {|SELECT member_a, member_b, reciprocity_ratio
      FROM mv_reciprocal_voters
      WHERE community_id = $1 AND reciprocity_ratio > $2
      ORDER BY reciprocity_ratio DESC|}

  let member_vote_concentration =
    t2 int64 int64
    ->? float @@
    {|SELECT herfindahl_index
      FROM mv_member_vote_stats
      WHERE member_id = $1 AND community_id = $2|}

  let top_influencers =
    t2 int64 int
    ->* t3 int64 int64 int @@
    {|SELECT influencer_id, influenced_id, net_influence
      FROM mv_influence_graph
      WHERE community_id = $1
      ORDER BY ABS(net_influence) DESC
      LIMIT $2|}

  let strong_pairs =
    t2 int64 float
    ->* t3 int64 int64 float @@
    {|SELECT member_a, member_b, bond_strength
      FROM mv_pair_strength
      WHERE community_id = $1 AND bond_strength > $2
      ORDER BY bond_strength DESC|}
end

let get_reciprocal_pairs (module C : Caqti_eio.CONNECTION) ~community_id
    ~min_ratio =
  let cid = Ids.Community_id.to_int64 community_id in
  match C.collect_list Q.reciprocal_pairs (cid, min_ratio) with
  | Ok rows ->
      Ok
        (List.map
           (fun (a, b, ratio) ->
             (Ids.Member_id.of_int64 a, Ids.Member_id.of_int64 b, ratio))
           rows)
  | Error err -> Error (Format.asprintf "%a" Caqti_error.pp err)

let get_vote_concentration (module C : Caqti_eio.CONNECTION) ~member_id
    ~community_id =
  let mid = Ids.Member_id.to_int64 member_id in
  let cid = Ids.Community_id.to_int64 community_id in
  match C.find_opt Q.member_vote_concentration (mid, cid) with
  | Ok v -> Ok (Option.value ~default:0.0 v)
  | Error err -> Error (Format.asprintf "%a" Caqti_error.pp err)
