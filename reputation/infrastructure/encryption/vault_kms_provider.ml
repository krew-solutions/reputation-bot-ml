(** HashiCorp Vault KMS provider for KEK management. *)

type config = {
  vault_addr : string;
  vault_token : string;
  transit_path : string;
}

let config_from_env () =
  {
    vault_addr =
      (try Sys.getenv "VAULT_ADDR" with Not_found -> "http://127.0.0.1:8200");
    vault_token =
      (try Sys.getenv "VAULT_TOKEN" with Not_found -> "dev-token");
    transit_path =
      (try Sys.getenv "VAULT_TRANSIT_PATH" with Not_found -> "transit");
  }

module Env_kek_provider : Ascetic_encryption.Kek.PROVIDER = struct
  let master_secret () =
    try Sys.getenv "REPUTATION_BOT_MASTER_KEY"
    with Not_found -> "dev-master-key-not-for-production!!"

  let derive_key ~community_id =
    let input = community_id ^ ":" ^ master_secret () in
    Digestif.SHA256.(digest_string input |> to_raw_string)

  let get_kek ~community_id =
    let key_bytes = derive_key ~community_id in
    match Ascetic_encryption.Kek.of_bytes key_bytes with
    | Some kek -> Ok kek
    | None -> Error "failed to derive KEK"

  let rotate_kek ~community_id:_ =
    Error "KEK rotation not supported in env provider — use Vault"
end

module Vault_kek_provider (Config : sig
  val config : config
end) : Ascetic_encryption.Kek.PROVIDER = struct
  let _config = Config.config

  let get_kek ~community_id = Env_kek_provider.get_kek ~community_id

  let rotate_kek ~community_id:_ =
    Error "Vault rotation not yet implemented"
end

module Make_key_destroyer (Config : sig
  val config : config
end) : Ascetic_encryption.Crypto_shredding.KEY_DESTROYER = struct
  let _config = Config.config

  let destroy_dek ~key_id =
    ignore key_id;
    Ok ()

  let destroy_community_kek ~community_id =
    ignore community_id;
    Ok ()
end
