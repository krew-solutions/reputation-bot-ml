module TC = Reputation_domain.Trigger_config
module VT = Reputation_domain.Vote_type

let vote_type = Alcotest.testable VT.pp VT.equal

let test_plus () =
  let result = TC.classify_word "+" TC.default in
  Alcotest.(check (option vote_type)) "+" (Some VT.Up) result

let test_minus () =
  let result = TC.classify_word "-" TC.default in
  Alcotest.(check (option vote_type)) "-" (Some VT.Down) result

let test_spasibo () =
  let result = TC.classify_word "спасибо" TC.default in
  Alcotest.(check (option vote_type)) "спасибо" (Some VT.Up) result

let test_ascii_case_insensitive () =
  (* ASCII case insensitivity works; Cyrillic case is handled by adapter *)
  let result = TC.classify_word "Thanks" TC.default in
  Alcotest.(check (option vote_type)) "Thanks" (Some VT.Up) result

let test_thanks () =
  let result = TC.classify_word "thanks" TC.default in
  Alcotest.(check (option vote_type)) "thanks" (Some VT.Up) result

let test_thx () =
  let result = TC.classify_word "thx" TC.default in
  Alcotest.(check (option vote_type)) "thx" (Some VT.Up) result

let test_unknown_word () =
  let result = TC.classify_word "hello" TC.default in
  Alcotest.(check (option vote_type)) "hello = None" None result

let test_positive_emoji () =
  let result = TC.classify_emoji "\u{1F44D}" TC.default in
  Alcotest.(check (option vote_type)) "thumbs up" (Some VT.Up) result

let test_negative_emoji () =
  let result = TC.classify_emoji "\u{1F44E}" TC.default in
  Alcotest.(check (option vote_type)) "thumbs down" (Some VT.Down) result

let test_unknown_emoji () =
  let result = TC.classify_emoji "\u{1F600}" TC.default in
  Alcotest.(check (option vote_type)) "unknown emoji" None result

let test_all_positive_words () =
  List.iter
    (fun word ->
      let result = TC.classify_word word TC.default in
      Alcotest.(check (option vote_type))
        (Printf.sprintf "%s = Up" word) (Some VT.Up) result)
    (TC.positive_words TC.default)

let () =
  Alcotest.run "Trigger_config"
    [
      ( "words",
        [
          Alcotest.test_case "plus" `Quick test_plus;
          Alcotest.test_case "minus" `Quick test_minus;
          Alcotest.test_case "спасибо" `Quick test_spasibo;
          Alcotest.test_case "ascii case insensitive" `Quick
            test_ascii_case_insensitive;
          Alcotest.test_case "thanks" `Quick test_thanks;
          Alcotest.test_case "thx" `Quick test_thx;
          Alcotest.test_case "unknown" `Quick test_unknown_word;
          Alcotest.test_case "all positive" `Quick test_all_positive_words;
        ] );
      ( "emojis",
        [
          Alcotest.test_case "positive emoji" `Quick test_positive_emoji;
          Alcotest.test_case "negative emoji" `Quick test_negative_emoji;
          Alcotest.test_case "unknown emoji" `Quick test_unknown_emoji;
        ] );
    ]
