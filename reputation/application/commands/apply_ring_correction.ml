(** Apply fraud ring correction to a set of members. *)

open Reputation_domain
open Ascetic_ddd.Result_ext

type t = {
  ring_member_ids : Ids.Member_id.t list;
  total_fraudulent_karma : Karma.t;
}

let handle (type uow) (deps : uow Deps.t) (uow : uow) (cmd : t) =
  let (module EventStore) = deps.event_store in
  let (module Clock) = deps.clock in
  let now = Clock.now () in
  let ring_size = List.length cmd.ring_member_ids in
  if ring_size < 2 then Ok ()
  else
    let correction_per_member =
      Ascetic_ddd.Decimal.div
        (Karma.to_decimal cmd.total_fraudulent_karma)
        (Ascetic_ddd.Decimal.of_int ring_size)
      |> Ascetic_ddd.Decimal.neg
      |> Karma.of_decimal
    in
    traverse
      (fun member_id ->
        let* member = Cast_vote.load_member deps uow member_id in
        let member_version = Member.version member in
        let member =
          Member.apply_correction member ~effective_delta:correction_per_member
            ~reason:"voting ring correction" ~now
        in
        EventStore.append uow
          ~aggregate_id:(Ids.Member_id.show member_id)
          ~expected_version:member_version
          (Member.uncommitted_events member))
      cmd.ring_member_ids
    |> Result.map (fun _ -> ())
