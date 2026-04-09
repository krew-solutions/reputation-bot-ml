(** Vote direction — up or down. *)

type t = Up | Down [@@deriving show, eq, ord]

let base_value = function Up -> 1 | Down -> -1
