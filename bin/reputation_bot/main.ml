(** Composition root — wires all dependencies and starts the bot. *)

open Reputation_domain

let () = Logs.set_reporter (Logs_fmt.reporter ())
let () = Logs.set_level (Some Logs.Info)

let db_uri =
  try Uri.of_string (Sys.getenv "DATABASE_URL")
  with Not_found -> Uri.of_string "postgresql://localhost/reputation_bot"

let telegram_token =
  try Sys.getenv "TELEGRAM_BOT_TOKEN"
  with Not_found ->
    Logs.warn (fun m -> m "TELEGRAM_BOT_TOKEN not set");
    ""

type pg_uow = Reputation_infra.Caqti_unit_of_work.t

let make_pg_deps () : pg_uow Reputation_app.Deps.t =
  let module ES = Reputation_infra.Event_store_pg.Make () in
  let module MsgRepo = Reputation_infra.Message_repository_pg.Make () in
  let module ComRepo = Reputation_infra.Community_repository_pg.Make () in
  let module IdMap = Reputation_infra.External_id_mapping_pg.Make () in
  let module FraudDet = Reputation_infra.Fraud_detection_pg.Make () in
  let module MemberRepo : Member_repository.S with type uow = pg_uow = struct
    type uow = pg_uow
    let find_by_id _ _ = Ok None
    let find_by_community _ _ _ = Ok None
    let save _ _ ~expected_version:_ = Ok ()
    let next_id (module C : Caqti_eio.CONNECTION) =
      let open Caqti_request.Infix in
      let open Caqti_type in
      match C.find (unit ->! int64 @@ "SELECT nextval('members_id_seq')") ()
      with
      | Ok id -> Ok (Ids.Member_id.of_int64 id)
      | Error err -> Error (Format.asprintf "%a" Caqti_error.pp err)
  end in
  let module ChatRepo : Chat_repository.S with type uow = pg_uow = struct
    type uow = pg_uow
    let find_by_id _ _ = Ok None
    let save _ _ ~expected_version:_ = Ok ()
    let next_id (module C : Caqti_eio.CONNECTION) =
      let open Caqti_request.Infix in
      let open Caqti_type in
      match C.find (unit ->! int64 @@ "SELECT nextval('chats_id_seq')") ()
      with
      | Ok id -> Ok (Ids.Chat_id.of_int64 id)
      | Error err -> Error (Format.asprintf "%a" Caqti_error.pp err)
  end in
  let module EventPub : Event_publisher.S with type uow = pg_uow = struct
    type uow = pg_uow
    let publish _ _ = Ok ()
  end in
  let module Percentile : Reputation_percentile_port.S with type uow = pg_uow = struct
    type uow = pg_uow
    let calculate_percentile _ _ _ ~exclude_default:_ = Ok 50.0
  end in
  {
    member_repo = (module MemberRepo);
    message_repo = (module MsgRepo);
    community_repo = (module ComRepo);
    chat_repo = (module ChatRepo);
    id_mapping = (module IdMap);
    event_publisher = (module EventPub);
    event_store = (module ES);
    fraud_detection = (module FraudDet);
    percentile = (module Percentile);
    clock = (module Ascetic_ddd.Clock.SystemClock);
  }

let bot_loop_single ~env ~bot ~deps ~conn ~trigger_config =
  let offset = ref 0 in
  let clock = Eio.Stdenv.mono_clock env in
  let uow = Reputation_infra.Caqti_unit_of_work.of_connection conn in
  Logs.info (fun m -> m "Bot started, polling for updates...");
  while true do
    match
      Telegram_adapter.Telegram_bot.get_updates bot ~offset:!offset ~timeout:30
    with
    | Error e ->
        Logs.err (fun m -> m "getUpdates error: %s" e);
        Eio.Time.Mono.sleep clock 5.0
    | Ok updates ->
        List.iter
          (fun (update : Telegram_adapter.Telegram_types.update) ->
            offset := update.update_id + 1;
            match
              Telegram_adapter.Telegram_update_handler.handle_update deps uow
                ~trigger_config update
            with
            | Ok (Some _response) ->
                (match update.message with
                | Some msg ->
                    ignore
                      (Telegram_adapter.Telegram_bot.send_message bot
                         ~chat_id:msg.chat.id ~text:"karma updated"
                         ~reply_to_message_id:(Some msg.message_id))
                | None -> ())
            | Ok None -> ()
            | Error e ->
                Logs.warn (fun m ->
                    m "Command error: %s" (Domain_error.show e)))
          updates
  done

let () =
  Eio_main.run @@ fun env ->
  Eio.Switch.run @@ fun sw ->
  let stdenv = (env :> Caqti_eio.stdenv) in
  match Caqti_eio_unix.connect ~sw ~stdenv db_uri with
  | Error err ->
      Logs.err (fun m -> m "DB connection failed: %a" Caqti_error.pp err);
      exit 1
  | Ok conn ->
      let client =
        Cohttp_eio.Client.make ~https:None (Eio.Stdenv.net env)
      in
      let bot =
        Telegram_adapter.Telegram_bot.create ~sw ~client ~token:telegram_token
      in
      let trigger_config = Trigger_config.default in
      let deps = make_pg_deps () in
      bot_loop_single ~env ~bot ~deps ~conn ~trigger_config
