(** Fraud score — bounded integer 0-100.

    Classifies member's fraud likelihood:
    - Clean: < 20
    - Suspicious: 20-49
    - LikelyFraud: 50-79
    - ConfirmedFraud: >= 80

    Gospel contracts:
    - [to_int] always returns a value in [\[0, 100\]]
    - [of_int n] returns [Some] iff [0 <= n <= 100]
    - [of_int_exn n] requires [0 <= n <= 100]
    - [of_int_clamped] always produces a valid score
    - [zero] produces score 0
    - [classify] partitions the range into four bands *)

type t [@@deriving show, eq, ord]

type classification = Clean | Suspicious | LikelyFraud | ConfirmedFraud
[@@deriving show, eq]

val to_int : t -> int
val of_int : int -> t option
val of_int_exn : int -> t
val of_int_clamped : int -> t
val zero : t
val classify : t -> classification
