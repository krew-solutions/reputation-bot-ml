(** Reaction type — an emoji with its base weight direction. *)

type direction = Positive | Negative [@@deriving show, eq, ord]

type t = {
  emoji : string;
  direction : direction;
}
[@@deriving show, eq, ord]

let create ~emoji ~direction = { emoji; direction }
let emoji t = t.emoji
let direction t = t.direction

let base_value t =
  match t.direction with Positive -> 1 | Negative -> -1
