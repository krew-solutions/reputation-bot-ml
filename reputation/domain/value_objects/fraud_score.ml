(** Fraud score — bounded 0-100. *)

module Inner = Ascetic_ddd.Bounded_int.Make (struct
  let min_value = 0
  let max_value = 100
  let name = "FraudScore"
end)

type t = Inner.t [@@deriving show, eq, ord]

type classification = Clean | Suspicious | LikelyFraud | ConfirmedFraud
[@@deriving show, eq]

let of_int = Inner.of_int
let of_int_exn = Inner.of_int_exn
let of_int_clamped = Inner.of_int_clamped
let to_int = Inner.to_int

let zero = Inner.of_int_exn 0

let classify t =
  let v = Inner.to_int t in
  if v < 20 then Clean
  else if v < 50 then Suspicious
  else if v < 80 then LikelyFraud
  else ConfirmedFraud
