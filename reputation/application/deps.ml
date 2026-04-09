(** Application layer dependency context.

    Handlers receive their dependencies through this record,
    which is constructed at the composition root.
    Each field is a first-class module satisfying a port. *)

type 'uow t = {
  member_repo : (module Reputation_domain.Member_repository.S with type uow = 'uow);
  message_repo : (module Reputation_domain.Message_repository.S with type uow = 'uow);
  community_repo : (module Reputation_domain.Community_repository.S with type uow = 'uow);
  chat_repo : (module Reputation_domain.Chat_repository.S with type uow = 'uow);
  id_mapping : (module Reputation_domain.External_id_mapping.S with type uow = 'uow);
  event_publisher : (module Reputation_domain.Event_publisher.S with type uow = 'uow);
  event_store : (module Reputation_domain.Event_store.S with type uow = 'uow);
  fraud_detection : (module Reputation_domain.Fraud_detection_port.S with type uow = 'uow);
  percentile : (module Reputation_domain.Reputation_percentile_port.S with type uow = 'uow);
  clock : (module Ascetic_ddd.Clock.S);
}
