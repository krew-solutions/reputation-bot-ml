(lang dune 3.16)

(name reputation_bot)

(generate_opam_files true)

(license MIT)

(authors "Ivan")

(source
 (uri "https://github.com/emacsway/reputation-bot"))

(package
 (name reputation_bot)
 (synopsis "Reputation Bot for expert communities")
 (description
  "A reference DDD application in OCaml demonstrating FP capabilities for building domain-driven systems. Manages reputation of community members through voting in messengers.")
 (depends
  (ocaml
   (>= 5.4.0))
  (dune
   (>= 3.16))
  (eio
   (>= 1.2))
  eio_main
  (ptime
   (>= 1.2))
  (uuidm
   (>= 0.9))
  (fmt
   (>= 0.9))
  (logs
   (>= 0.7))
  (alcotest
   (and
    (>= 1.7)
    :with-test))
  (qcheck
   (and
    (>= 0.21)
    :with-test))
  ppx_deriving
  menhir
  yojson
  mirage-crypto
  mirage-crypto-rng-eio))

(using menhir 3.0)
