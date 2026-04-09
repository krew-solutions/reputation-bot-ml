(** Trigger configuration — words and emojis that trigger reputation changes.

    Configurable per community. Each trigger module owns only
    its own parameters (no god-object config). *)

type t = {
  positive_words : string list;
  negative_words : string list;
  positive_emojis : string list;
  negative_emojis : string list;
}
[@@deriving show, eq]

let default =
  {
    positive_words =
      [
        "+"; "спасибо"; "спс"; "спасибочки"; "спасибки"; "благодарю";
        "пасиба"; "пасеба"; "посеба"; "благодарочка"; "thx"; "мерси";
        "выручил"; "сяп"; "сяб"; "сенк"; "сенкс"; "сяпки"; "сябки";
        "сенью"; "благодарствую"; "thank"; "thanks"; "класс";
      ];
    negative_words = [ "-" ];
    positive_emojis =
      [
        "\u{1F44D}"; (* 👍 *)
        "\u{1F64F}"; (* 🙏 *)
        "\u{1F91D}"; (* 🤝 *)
        "\u{1F44F}"; (* 👏 *)
        "\u{1F4AF}"; (* 💯 *)
        "\u{1F3C6}"; (* 🏆 *)
        "\u{1F60D}"; (* 😍 *)
        "\u{1F929}"; (* 🤩 *)
        "\u{1F525}"; (* 🔥 *)
        "\u{1F4A5}"; (* 💥 *)
        "\u{2764}\u{200D}\u{1F525}";  (* ❤‍🔥 *)
        "\u{2764}";  (* ❤ *)
        "\u{1F4DD}"; (* 📝 *)
        "\u{270D}";  (* ✍ *)
      ];
    negative_emojis =
      [
        "\u{1F44E}"; (* 👎 *)
        "\u{1F494}"; (* 💔 *)
        "\u{1F92E}"; (* 🤮 *)
        "\u{1F4A9}"; (* 💩 *)
      ];
  }

let positive_words t = t.positive_words
let negative_words t = t.negative_words
let positive_emojis t = t.positive_emojis
let negative_emojis t = t.negative_emojis

let word_matches w1 w2 =
  String.equal w1 w2
  || String.equal (String.lowercase_ascii w1) (String.lowercase_ascii w2)

let classify_word word t =
  if List.exists (fun w -> word_matches w word) t.positive_words
  then Some Vote_type.Up
  else if List.exists (fun w -> word_matches w word) t.negative_words
  then Some Vote_type.Down
  else None

let classify_emoji emoji t =
  if List.mem emoji t.positive_emojis then Some Vote_type.Up
  else if List.mem emoji t.negative_emojis then Some Vote_type.Down
  else None
