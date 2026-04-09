open Reputation_domain
open Test_support

let deps = In_memory_repos.make_deps ()

let ext_user =
  External_ids.External_user_id.create ~platform:"telegram" ~value:"12345"

let setup () =
  In_memory_repos.clear_all ();
  (* Create community *)
  let result =
    Reputation_app.Create_community.handle deps ()
      { name = "Test Community"; settings = None }
  in
  match result with
  | Ok r -> r.community_id
  | Error e -> Alcotest.fail (Domain_error.show e)

let test_register_new_member () =
  let community_id = setup () in
  let result =
    Reputation_app.Register_member.handle deps ()
      { external_user_id = ext_user; community_id }
  in
  match result with
  | Ok r ->
      Alcotest.(check bool) "valid member_id" true
        (Ids.Member_id.to_int (r.member_id) > 0)
  | Error e -> Alcotest.fail (Domain_error.show e)

let test_register_idempotent () =
  let community_id = setup () in
  let result1 =
    Reputation_app.Register_member.handle deps ()
      { external_user_id = ext_user; community_id }
    |> Result.get_ok
  in
  let result2 =
    Reputation_app.Register_member.handle deps ()
      { external_user_id = ext_user; community_id }
    |> Result.get_ok
  in
  Alcotest.(check bool) "same member_id" true
    (Ids.Member_id.equal result1.member_id result2.member_id)

let () =
  Alcotest.run "Register_member"
    [
      ( "handler",
        [
          Alcotest.test_case "register new" `Quick test_register_new_member;
          Alcotest.test_case "idempotent" `Quick test_register_idempotent;
        ] );
    ]
