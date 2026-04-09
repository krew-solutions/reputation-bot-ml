(** Reputation Infrastructure — PostgreSQL persistence, encryption, adapters. *)

(* Persistence *)
module Caqti_unit_of_work = Caqti_unit_of_work
module Event_store_pg = Event_store_pg
module Message_repository_pg = Message_repository_pg
module Community_repository_pg = Community_repository_pg
module External_id_mapping_pg = External_id_mapping_pg

(* Encryption *)
module Aes_gcm_provider = Aes_gcm_provider
module Vault_kms_provider = Vault_kms_provider

(* Fraud *)
module Fraud_detection_pg = Fraud_detection_pg
module Graph_queries = Graph_queries
