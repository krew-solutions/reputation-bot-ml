(** Domain identity types. *)

module Member_id = Ascetic_ddd.Entity_id.Make (struct
  let name = "Member"
end)

module Message_id = Ascetic_ddd.Entity_id.Make (struct
  let name = "Message"
end)

module Community_id = Ascetic_ddd.Entity_id.Make (struct
  let name = "Community"
end)

module Chat_id = Ascetic_ddd.Entity_id.Make (struct
  let name = "Chat"
end)

module Vote_id = Ascetic_ddd.Entity_id.Make (struct
  let name = "Vote"
end)

module Reaction_id = Ascetic_ddd.Entity_id.Make (struct
  let name = "Reaction"
end)
