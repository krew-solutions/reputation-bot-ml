(** In-memory repository implementations for testing.

    All repos share a single [unit] as the UoW type. *)

open Reputation_domain

(* In-memory event store for Member ES *)
module In_memory_event_store : sig
  include Event_store.S with type uow = unit
  val clear : unit -> unit
end = struct
  type uow = unit

  let events : (string, Member.event Ascetic_ddd.Domain_event.t list) Hashtbl.t =
    Hashtbl.create 16

  let versions : (string, int) Hashtbl.t = Hashtbl.create 16

  let clear () =
    Hashtbl.clear events;
    Hashtbl.clear versions

  let append () ~aggregate_id ~expected_version new_events =
    let current_version =
      match Hashtbl.find_opt versions aggregate_id with
      | Some v -> v
      | None -> 0
    in
    if current_version <> expected_version then
      Error
        (Domain_error.Concurrency_conflict
           {
             expected_version;
             actual_version = current_version;
           })
    else begin
      let existing =
        match Hashtbl.find_opt events aggregate_id with
        | Some es -> es
        | None -> []
      in
      Hashtbl.replace events aggregate_id (existing @ new_events);
      Hashtbl.replace versions aggregate_id
        (current_version + List.length new_events);
      Ok ()
    end

  let load_events () ~aggregate_id ~since_version =
    match Hashtbl.find_opt events aggregate_id with
    | None -> Ok []
    | Some es ->
        Ok
          (List.filter
             (fun e -> e.Ascetic_ddd.Domain_event.aggregate_version > since_version)
             es)

  let save_snapshot () ~aggregate_id:_ ~version:_ ~data:_ = Ok ()
  let load_snapshot () ~aggregate_id:_ = Ok None
end

(* In-memory message repository *)
module In_memory_message_repo : sig
  include Message_repository.S with type uow = unit
  val clear : unit -> unit
end = struct
  type uow = unit

  let messages : (int64, Message.t) Hashtbl.t = Hashtbl.create 16
  let next_counter = ref 1L

  let clear () =
    Hashtbl.clear messages;
    next_counter := 1L

  let find_by_id () id =
    Ok (Hashtbl.find_opt messages (Ids.Message_id.to_int64 id))

  let save () msg ~expected_version =
    let id = Ids.Message_id.to_int64 (Message.id msg) in
    let current_version =
      match Hashtbl.find_opt messages id with
      | Some m -> Message.version m
      | None -> 0
    in
    if current_version <> expected_version then
      Error
        (Domain_error.Concurrency_conflict
           { expected_version; actual_version = current_version })
    else begin
      Hashtbl.replace messages id (Message.clear_uncommitted_events msg);
      Ok ()
    end

  let next_id () =
    let id = !next_counter in
    next_counter := Int64.add id 1L;
    Ok (Ids.Message_id.of_int64 id)
end

(* In-memory community repository *)
module In_memory_community_repo : sig
  include Community_repository.S with type uow = unit
  val clear : unit -> unit
end = struct
  type uow = unit

  let communities : (int64, Community.t) Hashtbl.t = Hashtbl.create 16
  let next_counter = ref 1L

  let clear () =
    Hashtbl.clear communities;
    next_counter := 1L

  let find_by_id () id =
    Ok (Hashtbl.find_opt communities (Ids.Community_id.to_int64 id))

  let save () community ~expected_version =
    let id = Ids.Community_id.to_int64 (Community.id community) in
    let current_version =
      match Hashtbl.find_opt communities id with
      | Some c -> Community.version c
      | None -> 0
    in
    if current_version <> expected_version then
      Error
        (Domain_error.Concurrency_conflict
           { expected_version; actual_version = current_version })
    else begin
      Hashtbl.replace communities id
        (Community.clear_uncommitted_events community);
      Ok ()
    end

  let next_id () =
    let id = !next_counter in
    next_counter := Int64.add id 1L;
    Ok (Ids.Community_id.of_int64 id)
end

(* In-memory chat repository *)
module In_memory_chat_repo : sig
  include Chat_repository.S with type uow = unit
  val clear : unit -> unit
end = struct
  type uow = unit

  let chats : (int64, Chat.t) Hashtbl.t = Hashtbl.create 16
  let next_counter = ref 1L

  let clear () =
    Hashtbl.clear chats;
    next_counter := 1L

  let find_by_id () id =
    Ok (Hashtbl.find_opt chats (Ids.Chat_id.to_int64 id))

  let find_by_external_id () ext_id =
    let found =
      Hashtbl.fold
        (fun _ chat acc ->
          match acc with
          | Some _ -> acc
          | None ->
              if External_ids.External_chat_id.equal
                   (Chat.external_chat_id chat) ext_id
              then Some chat
              else None)
        chats None
    in
    Ok found

  let save () chat ~expected_version =
    let id = Ids.Chat_id.to_int64 (Chat.id chat) in
    let current_version =
      match Hashtbl.find_opt chats id with
      | Some c -> Chat.version c
      | None -> 0
    in
    if current_version <> expected_version then
      Error
        (Domain_error.Concurrency_conflict
           { expected_version; actual_version = current_version })
    else begin
      Hashtbl.replace chats id chat;
      Ok ()
    end

  let next_id () =
    let id = !next_counter in
    next_counter := Int64.add id 1L;
    Ok (Ids.Chat_id.of_int64 id)
end

(* In-memory member repository — delegates to event store *)
module In_memory_member_repo : sig
  include Member_repository.S with type uow = unit
  val clear : unit -> unit
end = struct
  type uow = unit

  let next_counter = ref 1L

  let clear () = next_counter := 1L

  let find_by_id () _id = Ok None  (* Use event store for ES aggregates *)
  let find_by_community () _id _cid = Ok None

  let save () _member ~expected_version:_ = Ok ()  (* ES: save via event store *)

  let next_id () =
    let id = !next_counter in
    next_counter := Int64.add id 1L;
    Ok (Ids.Member_id.of_int64 id)
end

(* In-memory ID mapping *)
module In_memory_id_mapping : sig
  include External_id_mapping.S with type uow = unit
  val clear : unit -> unit
end = struct
  type uow = unit

  let member_mappings :
    (string, Ids.Member_id.t) Hashtbl.t = Hashtbl.create 16

  let message_mappings :
    (string, Ids.Message_id.t) Hashtbl.t = Hashtbl.create 16

  let clear () =
    Hashtbl.clear member_mappings;
    Hashtbl.clear message_mappings

  let member_key ext_id community_id =
    Printf.sprintf "%s:%s:%s"
      (External_ids.External_user_id.platform ext_id)
      (External_ids.External_user_id.value ext_id)
      (Ids.Community_id.show community_id)

  let find_member_id () ext_id community_id =
    Ok (Hashtbl.find_opt member_mappings (member_key ext_id community_id))

  let find_message_id () ext_id =
    let key =
      Printf.sprintf "%s:%s"
        (External_ids.External_message_id.platform ext_id)
        (External_ids.External_message_id.value ext_id)
    in
    Ok (Hashtbl.find_opt message_mappings key)

  let save_member_mapping () ext_id member_id community_id =
    Hashtbl.replace member_mappings (member_key ext_id community_id) member_id;
    Ok ()

  let save_message_mapping () ext_id message_id =
    let key =
      Printf.sprintf "%s:%s"
        (External_ids.External_message_id.platform ext_id)
        (External_ids.External_message_id.value ext_id)
    in
    Hashtbl.replace message_mappings key message_id;
    Ok ()
end

(* Noop event publisher *)
module In_memory_event_publisher : sig
  include Event_publisher.S with type uow = unit
  val published : unit -> Domain_events.t Ascetic_ddd.Domain_event.t list
  val clear : unit -> unit
end = struct
  type uow = unit

  let events = ref []

  let publish () new_events =
    events := !events @ new_events;
    Ok ()

  let published () = !events

  let clear () = events := []
end

(* Noop fraud detection *)
module In_memory_fraud_detection : Fraud_detection_port.S with type uow = unit =
struct
  type uow = unit

  let calculate_fraud_factors () _member_id _community_id =
    Ok Fraud_factors.zero

  let detect_voting_rings () _community_id = Ok []
end

(* Noop percentile *)
module In_memory_percentile : Reputation_percentile_port.S with type uow = unit =
struct
  type uow = unit

  let calculate_percentile () _member_id _community_id ~exclude_default:_ =
    Ok 80.0  (* Above default 75% threshold *)
end

(* Fixed clock for tests *)
let test_time = Ptime.of_float_s 1_700_000_000.0 |> Option.get

module Test_clock : Ascetic_ddd.Clock.S = struct
  let now () = test_time
end

(* Build deps record *)
let make_deps () : unit Reputation_app.Deps.t =
  {
    member_repo = (module In_memory_member_repo);
    message_repo = (module In_memory_message_repo);
    community_repo = (module In_memory_community_repo);
    chat_repo = (module In_memory_chat_repo);
    id_mapping = (module In_memory_id_mapping);
    event_publisher = (module In_memory_event_publisher);
    event_store = (module In_memory_event_store);
    fraud_detection = (module In_memory_fraud_detection);
    percentile = (module In_memory_percentile);
    clock = (module Test_clock);
  }

let clear_all () =
  In_memory_event_store.clear ();
  In_memory_message_repo.clear ();
  In_memory_community_repo.clear ();
  In_memory_chat_repo.clear ();
  In_memory_member_repo.clear ();
  In_memory_id_mapping.clear ();
  In_memory_event_publisher.clear ()
