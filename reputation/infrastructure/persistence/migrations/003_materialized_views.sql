-- 003: Materialized views for anti-fraud analysis

BEGIN;

-- Base graph view: voter -> author edges with counts
CREATE MATERIALIZED VIEW mv_vote_edges AS
SELECT
    v.voter_id,
    m.author_id,
    m.chat_id,
    ch.community_id,
    COUNT(*) AS vote_count,
    COUNT(*) FILTER (WHERE v.vote_type = 'up') AS upvote_count,
    COUNT(*) FILTER (WHERE v.vote_type = 'down') AS downvote_count,
    MIN(v.voted_at) AS first_vote,
    MAX(v.voted_at) AS last_vote
FROM votes v
JOIN messages m ON m.id = v.message_id
JOIN chats ch ON ch.id = m.chat_id
GROUP BY v.voter_id, m.author_id, m.chat_id, ch.community_id;

CREATE UNIQUE INDEX idx_mv_vote_edges ON mv_vote_edges(voter_id, author_id, community_id);

-- Reciprocal voting pairs
CREATE MATERIALIZED VIEW mv_reciprocal_voters AS
SELECT
    a.voter_id AS member_a,
    a.author_id AS member_b,
    a.community_id,
    a.upvote_count AS a_to_b,
    b.upvote_count AS b_to_a,
    LEAST(a.upvote_count, b.upvote_count)::float /
        GREATEST(a.upvote_count, b.upvote_count)::float AS reciprocity_ratio
FROM mv_vote_edges a
JOIN mv_vote_edges b
    ON a.voter_id = b.author_id
    AND a.author_id = b.voter_id
    AND a.community_id = b.community_id
WHERE a.voter_id < a.author_id  -- Avoid duplicates
    AND a.upvote_count > 0
    AND b.upvote_count > 0;

CREATE UNIQUE INDEX idx_mv_reciprocal ON mv_reciprocal_voters(member_a, member_b, community_id);

-- Member vote statistics
CREATE MATERIALIZED VIEW mv_member_vote_stats AS
SELECT
    voter_id AS member_id,
    community_id,
    COUNT(DISTINCT author_id) AS unique_authors_voted_for,
    SUM(upvote_count) AS total_upvotes_given,
    SUM(downvote_count) AS total_downvotes_given,
    -- Herfindahl index for vote concentration
    SUM(upvote_count * upvote_count)::float /
        NULLIF(SUM(upvote_count) * SUM(upvote_count), 0)::float AS herfindahl_index
FROM mv_vote_edges
GROUP BY voter_id, community_id;

CREATE UNIQUE INDEX idx_mv_member_stats ON mv_member_vote_stats(member_id, community_id);

-- Influence graph: who affects whose karma the most
CREATE MATERIALIZED VIEW mv_influence_graph AS
SELECT
    voter_id AS influencer_id,
    author_id AS influenced_id,
    community_id,
    SUM(vote_count) AS total_interactions,
    SUM(upvote_count) - SUM(downvote_count) AS net_influence
FROM mv_vote_edges
GROUP BY voter_id, author_id, community_id
HAVING SUM(vote_count) >= 3;

CREATE UNIQUE INDEX idx_mv_influence ON mv_influence_graph(influencer_id, influenced_id, community_id);

-- Pair strength for clique detection (geometric mean of mutual votes)
CREATE MATERIALIZED VIEW mv_pair_strength AS
SELECT
    r.member_a,
    r.member_b,
    r.community_id,
    r.a_to_b,
    r.b_to_a,
    SQRT(r.a_to_b::float * r.b_to_a::float) AS bond_strength
FROM mv_reciprocal_voters r
WHERE r.a_to_b >= 2 AND r.b_to_a >= 2;

CREATE UNIQUE INDEX idx_mv_pair_strength ON mv_pair_strength(member_a, member_b, community_id);

-- Function to refresh all anti-fraud views (call via pg_cron hourly)
CREATE OR REPLACE FUNCTION refresh_anti_fraud_views()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_vote_edges;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_reciprocal_voters;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_member_vote_stats;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_influence_graph;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_pair_strength;
END;
$$ LANGUAGE plpgsql;

COMMIT;
