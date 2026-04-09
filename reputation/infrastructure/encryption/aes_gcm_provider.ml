(** AES-256-GCM encryption provider using mirage-crypto. *)

module GCM = Mirage_crypto.AES.GCM

let encrypt ~(dek : Ascetic_encryption.Dek.t) (plaintext : string) : string =
  let key = GCM.of_secret (Ascetic_encryption.Dek.key_bytes dek) in
  let nonce = Ascetic_encryption.Dek.nonce dek in
  GCM.authenticate_encrypt ~key ~nonce plaintext

let decrypt ~(dek : Ascetic_encryption.Dek.t) (ciphertext : string) : string option =
  if String.length ciphertext < 16 then None
  else
    let key = GCM.of_secret (Ascetic_encryption.Dek.key_bytes dek) in
    let nonce = Ascetic_encryption.Dek.nonce dek in
    GCM.authenticate_decrypt ~key ~nonce ciphertext
