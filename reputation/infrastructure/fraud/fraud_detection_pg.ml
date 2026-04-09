(** PostgreSQL fraud detection backed by materialized views. *)

open Reputation_domain

module Q = struct
  open Caqti_request.Infix
  open Caqti_type

  let calculate_fraud_score =
    t2 int64 int64 ->? t5 int int int int int @@
    {|SELECT reciprocal_voting, vote_concentration, ring_participation,
             karma_ratio_anomaly, velocity_anomaly
      FROM calculate_fraud_score(?, ?)|}

  let find_voting_rings =
    int64 ->* string @@
    {|SELECT array_to_string(ring_members, ',') FROM find_voting_rings(?)|}
end

let parse_member_ids (s : string) : Ids.Member_id.t list =
  String.split_on_char ',' s
  |> List.filter_map (fun part ->
         try Some (Ids.Member_id.of_int64 (Int64.of_string (String.trim part)))
         with _ -> None)

module Make () : Fraud_detection_port.S with type uow = Caqti_unit_of_work.t = struct
  type uow = Caqti_unit_of_work.t

  let calculate_fraud_factors (module C : Caqti_eio.CONNECTION) member_id community_id =
    match C.find_opt Q.calculate_fraud_score
            (Ids.Member_id.to_int64 member_id, Ids.Community_id.to_int64 community_id) with
    | Ok (Some (rv, vc, rp, kra, va)) ->
        Ok (Fraud_factors.create ~reciprocal_voting:rv ~vote_concentration:vc
              ~ring_participation:rp ~karma_ratio_anomaly:kra ~velocity_anomaly:va)
    | Ok None -> Ok Fraud_factors.zero
    | Error err -> Error (Format.asprintf "%a" Caqti_error.pp err)

  let detect_voting_rings (module C : Caqti_eio.CONNECTION) community_id =
    match C.collect_list Q.find_voting_rings (Ids.Community_id.to_int64 community_id) with
    | Ok rows ->
        Ok (List.filter (fun r -> List.length r >= 2) (List.map parse_member_ids rows))
    | Error err -> Error (Format.asprintf "%a" Caqti_error.pp err)
end
