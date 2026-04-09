-- 001: Initial schema for reputation bot
-- Communities, chats, members, messages, votes, reactions, ID mappings

BEGIN;

CREATE TABLE communities (
    id BIGSERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    settings JSONB NOT NULL DEFAULT '{}',
    version INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE chats (
    id BIGSERIAL PRIMARY KEY,
    community_id BIGINT NOT NULL REFERENCES communities(id),
    platform TEXT NOT NULL,
    external_chat_id TEXT NOT NULL,
    version INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (platform, external_chat_id)
);

CREATE INDEX idx_chats_community ON chats(community_id);
CREATE INDEX idx_chats_external ON chats(platform, external_chat_id);

CREATE TABLE members (
    id BIGSERIAL PRIMARY KEY,
    community_id BIGINT NOT NULL REFERENCES communities(id),
    version INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (id, community_id)
);

CREATE INDEX idx_members_community ON members(community_id);

CREATE TABLE messages (
    id BIGSERIAL PRIMARY KEY,
    author_id BIGINT NOT NULL REFERENCES members(id),
    chat_id BIGINT NOT NULL REFERENCES chats(id),
    version INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_messages_author ON messages(author_id);
CREATE INDEX idx_messages_chat ON messages(chat_id);

CREATE TABLE votes (
    id BIGSERIAL PRIMARY KEY,
    message_id BIGINT NOT NULL REFERENCES messages(id),
    voter_id BIGINT NOT NULL REFERENCES members(id),
    vote_type TEXT NOT NULL CHECK (vote_type IN ('up', 'down')),
    weight INTEGER NOT NULL, -- Decimal raw (scaled by 10000)
    voted_at TIMESTAMPTZ NOT NULL,
    UNIQUE (message_id, voter_id)
);

CREATE INDEX idx_votes_message ON votes(message_id);
CREATE INDEX idx_votes_voter ON votes(voter_id);
CREATE INDEX idx_votes_voter_time ON votes(voter_id, voted_at);

CREATE TABLE reactions (
    id BIGSERIAL PRIMARY KEY,
    message_id BIGINT NOT NULL REFERENCES messages(id),
    reactor_id BIGINT NOT NULL REFERENCES members(id),
    emoji TEXT NOT NULL,
    direction TEXT NOT NULL CHECK (direction IN ('positive', 'negative')),
    weight INTEGER NOT NULL, -- Decimal raw (scaled by 10000)
    reacted_at TIMESTAMPTZ NOT NULL,
    UNIQUE (message_id, reactor_id, emoji)
);

CREATE INDEX idx_reactions_message ON reactions(message_id);
CREATE INDEX idx_reactions_reactor ON reactions(reactor_id);

-- External ID mappings (messenger-agnostic)
CREATE TABLE external_member_mappings (
    platform TEXT NOT NULL,
    external_user_id TEXT NOT NULL,
    community_id BIGINT NOT NULL REFERENCES communities(id),
    member_id BIGINT NOT NULL REFERENCES members(id),
    PRIMARY KEY (platform, external_user_id, community_id)
);

CREATE TABLE external_message_mappings (
    platform TEXT NOT NULL,
    external_message_id TEXT NOT NULL,
    message_id BIGINT NOT NULL REFERENCES messages(id),
    PRIMARY KEY (platform, external_message_id)
);

COMMIT;
