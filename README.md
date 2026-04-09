# Reputation Bot

Reference application demonstrating Functional Programming capabilities for Domain-Driven Design in OCaml. A reputation/karma bot for expert communities, designed for Telegram with a messenger-agnostic architecture.

## Architecture

```
reputation-bot/
  ascetic_ddd/              Reusable DDD building blocks (future standalone library)
    encryption/             KEK/DEK, Forgettable Payloads, Crypto-Shredding
    specification/          Specification Pattern: AST, evaluator, SQL compiler, parser
  reputation/               Reputation component
    domain/                 Domain Layer (zero external dependencies)
      value_objects/        Karma, DualKarma, FraudScore, VotingPower, TriggerConfig...
      entities/             VoteRecord, ReactionRecord
      aggregates/           Member (Event Sourced), Message, Community, Chat
      events/               13 domain event types
      errors/               14 domain error types
      ports/                9 repository/service port interfaces
      services/             KarmaCalculation, FraudScoring
    application/            Application Layer (CQRS)
      commands/             CastVote, RegisterMember, AddReaction, UpdateFraudScore...
      queries/              GetMemberKarma, GetLeaderboard, GetMemberFraudStatus
      services/             VoteApplicationService, FraudApplicationService
    infrastructure/         Infrastructure Layer
      persistence/          Caqti/PostgreSQL repositories, Event Store, migrations
      encryption/           AES-256-GCM provider, HashiCorp Vault KMS
      fraud/                Fraud detection via materialized views + recursive CTEs
    adapters/
      telegram/             Telegram Bot API adapter (Eio + cohttp)
  bin/reputation_bot/       Composition root
  test/
    unit/                   Unit tests (domain, application, ascetic_ddd)
    acceptance/             BDD/Gherkin acceptance tests
    support/                In-memory test infrastructure
```

**Patterns applied**: DDD, CQRS, Event Sourcing, Railway-Oriented Programming, Hexagonal Architecture, Specification Pattern (dual interpretation), Optimistic Offline Locking, Unit of Work, Value Objects, Forgettable Payloads, Crypto-Shredding.

## Prerequisites

- **OCaml** >= 5.4.0
- **opam** >= 2.1
- **PostgreSQL** >= 15
- **HashiCorp Vault** (optional, for production key management)

## Installation

### 1. OCaml toolchain

```bash
# Install opam if not present
bash -c "sh <(curl -fsSL https://opam.ocaml.org/install.sh)"

# Create a switch with OCaml 5.4
opam switch create . ocaml-base-compiler.5.4.1
eval $(opam env)
```

### 2. Dependencies

```bash
opam install -y \
  dune eio eio_main \
  caqti caqti-driver-postgresql caqti-eio \
  cohttp-eio yojson \
  ptime alcotest qcheck \
  fmt logs uuidm ppx_deriving \
  menhir mirage-crypto mirage-crypto-rng-eio \
  digestif gospel
```

### 3. Build

```bash
dune build
```

### 4. Database setup

```bash
# Create database
createdb reputation_bot

# Run migrations in order
psql reputation_bot < reputation/infrastructure/persistence/migrations/001_initial_schema.sql
psql reputation_bot < reputation/infrastructure/persistence/migrations/002_event_store.sql
psql reputation_bot < reputation/infrastructure/persistence/migrations/003_materialized_views.sql
psql reputation_bot < reputation/infrastructure/persistence/migrations/004_fraud_functions.sql
```

## Configuration

All configuration is via environment variables:

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DATABASE_URL` | Yes | `postgresql://localhost/reputation_bot` | PostgreSQL connection URI |
| `TELEGRAM_BOT_TOKEN` | Yes | — | Telegram Bot API token from @BotFather |
| `VAULT_ADDR` | No | `http://127.0.0.1:8200` | HashiCorp Vault address |
| `VAULT_TOKEN` | No | `dev-token` | Vault authentication token |
| `REPUTATION_BOT_MASTER_KEY` | No | dev default | Master key for KEK derivation (dev mode) |

### Telegram Bot Setup

1. Create a bot via [@BotFather](https://t.me/BotFather)
2. Get the API token
3. Set allowed updates: the bot needs `message` and `message_reaction` permissions
4. Add the bot to your group chat as admin

### Community Configuration

Each community has its own settings (configured in `GroupSettings`):

- **Voting power thresholds**: karma levels for Newcomer/Regular/Trusted/Elder tiers (default: 10/100/500)
- **Budget windows**: hourly (5), daily (20), weekly (100) vote limits
- **Voting window**: time after message creation during which votes are accepted (default: 48h)
- **Reaction coefficient**: multiplier for reaction-based votes (default: 0.1)
- **Reaction percentile**: minimum reputation percentile to vote via reactions (default: 75%)
- **Trigger words/emojis**: configurable positive and negative triggers

## Running

```bash
export DATABASE_URL="postgresql://user:pass@localhost/reputation_bot"
export TELEGRAM_BOT_TOKEN="your-token-here"

dune exec bin/reputation_bot/main.exe
```

The bot will start long-polling Telegram for updates.

## How It Works

**Upvote**: Reply to a message with `+`, `спасибо`, `thanks`, `thx`, or any configured trigger word/emoji.

**Downvote**: Reply with `-` or a negative emoji (👎, 💔, 🤮, 💩).

**Reactions**: React to a message with a positive emoji (👍, 🙏, 🤝, 👏, 💯, 🔥...) — requires being above the 75th reputation percentile.

The voting power of each member depends on their effective karma:

| Tier | Min Karma | Multiplier |
|------|-----------|------------|
| Newcomer | 0 | 0.5x |
| Regular | 10 | 1.0x |
| Trusted | 100 | 1.5x |
| Elder | 500 | 2.0x |

### Anti-Fraud

The system detects fraudulent behavior through five signals:

1. **Reciprocal voting** — A↔B mutual upvote detection
2. **Vote concentration** — Herfindahl index on vote distribution
3. **Ring participation** — cycle detection (A→B→C→A) via recursive CTEs
4. **Karma ratio anomaly** — high karma with few unique voters
5. **Velocity anomaly** — rapid voting bursts

Fraud score (0-100) determines the **taint factor** applied to votes:

| Classification | Score | Taint Factor |
|---------------|-------|--------------|
| Clean | 0-19 | 100% |
| Suspicious | 20-49 | 70% |
| Likely Fraud | 50-79 | 30% |
| Confirmed Fraud | 80-100 | 0% (blocked) |

**DualKarma**: Public karma (shown to user) is never reduced by fraud. Effective karma (used for voting power and leaderboards) is adjusted. This ensures users never see their karma decrease due to fraud detection.

## Testing

### Run all tests

```bash
dune test
```

### Run specific test suites

```bash
# Unit tests
dune exec test/unit/domain/test_member.exe
dune exec test/unit/domain/test_dual_karma.exe
dune exec test/unit/domain/test_message.exe
dune exec test/unit/domain/test_fraud_score.exe

# Application layer tests
dune exec test/unit/application/test_cast_vote_handler.exe

# Specification pattern tests
dune exec test/unit/ascetic_ddd/test_spec.exe

# BDD acceptance tests
dune exec test/acceptance/acceptance_tests.exe
```

### Formal verification

```bash
# Run Why3 proofs (requires why3 + alt-ergo)
dune build @verify
```

This proves 52 verification conditions for key domain invariants:

- **DualKarma** (33 VCs): `effective <= public` always holds, `receive` and `apply_correction` preserve invariants, public/effective always non-negative
- **FraudScore + TaintFactor** (15 VCs): score bounded [0,100], classification correctness, taint mapping correctness, confirmed fraud zeroes output
- **SlidingWindow** (4 VCs): empty budget never exhausted, action recording correctness

All proofs are fully automatic via Alt-Ergo SMT solver (no manual `sorry`/`admitted`).

### Test structure

- **150 tests** across 14 test suites
- **52 formal verification conditions** (Why3 + Alt-Ergo)
- **Unit tests**: value objects, aggregates, domain services, command handlers
- **Acceptance tests**: Gherkin-style BDD scenarios (vote casting, budget exhaustion, self-vote prevention, fraud detection, cross-chat karma)
- **Sociable tests**: real domain + application layers with in-memory infrastructure (no mocks except external network adapters)

## GDPR & Encryption

- **KEK** (Key Encryption Key): one per community, stored in HashiCorp Vault
- **DEK** (Data Encryption Key): one per aggregate, encrypted with KEK, stored in PostgreSQL
- **Forgettable Payloads**: PII in event store encrypted with DEK; destroying DEK = right to be forgotten
- **Crypto-Shredding**: destroy community KEK to make all community data unreadable

## Specification Pattern

The built-in specification pattern supports dual interpretation:

```
# Parse a spec from a string
platform == "android" && enrolled == true

# Evaluate in-memory against a value tree
Spec_eval.satisfies device spec  (* => true/false *)

# Compile to SQL
Spec_sql.compile schema spec |> Spec_sql.to_sql
(* => SELECT r0.* FROM devices r0 WHERE r0.platform = $1 AND r0.enrolled = $2 *)

# Parameterized queries
platform == $target_platform
```

Supports: nested paths, `exists`/`forall` quantifiers, composite keys, `$placeholder` parameters, function calls (`size`, `contains`, `startsWith`).

## License

MIT
