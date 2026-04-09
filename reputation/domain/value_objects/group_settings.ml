(** Group settings — per-community configuration. *)

type t = {
  voting_power_thresholds : Voting_power_thresholds.t;
  budget_window_set : Budget_window_set.t;
  voting_window : Voting_window.t;
  trigger_config : Trigger_config.t;
  reaction_coefficient : float;
  reaction_percentile : Reaction_percentile.t;
}

let pp fmt t =
  Format.fprintf fmt
    "{ voting_power_thresholds = %a; budget_window_set = %a; \
     voting_window = %a; reaction_coefficient = %f; reaction_percentile = %a }"
    Voting_power_thresholds.pp t.voting_power_thresholds
    Budget_window_set.pp t.budget_window_set
    Voting_window.pp t.voting_window
    t.reaction_coefficient
    Reaction_percentile.pp t.reaction_percentile

let show t = Format.asprintf "%a" pp t

let equal a b =
  Voting_power_thresholds.equal a.voting_power_thresholds b.voting_power_thresholds
  && Budget_window_set.equal a.budget_window_set b.budget_window_set
  && Voting_window.equal a.voting_window b.voting_window
  && Trigger_config.equal a.trigger_config b.trigger_config
  && Float.equal a.reaction_coefficient b.reaction_coefficient
  && Reaction_percentile.equal a.reaction_percentile b.reaction_percentile

let default =
  {
    voting_power_thresholds = Voting_power_thresholds.default;
    budget_window_set = Budget_window_set.default;
    voting_window = Voting_window.default;
    trigger_config = Trigger_config.default;
    reaction_coefficient = 0.1;
    reaction_percentile = Reaction_percentile.default;
  }

let voting_power_thresholds t = t.voting_power_thresholds
let budget_window_set t = t.budget_window_set
let voting_window t = t.voting_window
let trigger_config t = t.trigger_config
let reaction_coefficient t = t.reaction_coefficient
let reaction_percentile t = t.reaction_percentile
