(** External identity value objects.

    Each external ID pairs a platform name with the platform-specific
    identifier value. This allows the domain to be messenger-agnostic. *)

module External_user_id = struct
  type t = { platform : string; value : string } [@@deriving show, eq, ord]

  let create ~platform ~value = { platform; value }
  let platform t = t.platform
  let value t = t.value
end

module External_chat_id = struct
  type t = { platform : string; value : string } [@@deriving show, eq, ord]

  let create ~platform ~value = { platform; value }
  let platform t = t.platform
  let value t = t.value
end

module External_message_id = struct
  type t = { platform : string; value : string } [@@deriving show, eq, ord]

  let create ~platform ~value = { platform; value }
  let platform t = t.platform
  let value t = t.value
end
