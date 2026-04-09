-- 002: Event store for event-sourced aggregates (Member)

BEGIN;

CREATE TABLE event_store (
    id BIGSERIAL PRIMARY KEY,
    aggregate_id TEXT NOT NULL,
    aggregate_version INTEGER NOT NULL,
    event_type TEXT NOT NULL,
    payload BYTEA NOT NULL,           -- Encrypted event payload
    dek_id TEXT,                       -- DEK identifier for decryption
    occurred_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (aggregate_id, aggregate_version)
);

CREATE INDEX idx_event_store_aggregate ON event_store(aggregate_id, aggregate_version);

CREATE TABLE event_store_snapshots (
    aggregate_id TEXT PRIMARY KEY,
    version INTEGER NOT NULL,
    data BYTEA NOT NULL,               -- Encrypted snapshot
    dek_id TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Encryption key store: DEKs encrypted by KEK
CREATE TABLE encryption_keys (
    key_id TEXT PRIMARY KEY,
    community_id BIGINT REFERENCES communities(id),
    encrypted_dek BYTEA NOT NULL,      -- DEK encrypted with community KEK
    key_type TEXT NOT NULL CHECK (key_type IN ('aggregate', 'community')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE INDEX idx_encryption_keys_community ON encryption_keys(community_id);

COMMIT;
