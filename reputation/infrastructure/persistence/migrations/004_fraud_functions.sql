-- 004: Fraud detection functions

BEGIN;

-- Detect voting rings (cycles of length 3-5) via recursive CTE
CREATE OR REPLACE FUNCTION find_voting_rings(p_community_id BIGINT, max_depth INTEGER DEFAULT 5)
RETURNS TABLE(ring_members BIGINT[]) AS $$
WITH RECURSIVE ring_search AS (
    -- Start from each edge
    SELECT
        e.voter_id AS start_node,
        e.author_id AS current_node,
        ARRAY[e.voter_id, e.author_id] AS path,
        2 AS depth
    FROM mv_vote_edges e
    WHERE e.community_id = p_community_id
        AND e.upvote_count >= 2

    UNION ALL

    -- Extend the path
    SELECT
        rs.start_node,
        e.author_id AS current_node,
        rs.path || e.author_id,
        rs.depth + 1
    FROM ring_search rs
    JOIN mv_vote_edges e
        ON e.voter_id = rs.current_node
        AND e.community_id = p_community_id
        AND e.upvote_count >= 2
        AND NOT (e.author_id = ANY(rs.path[2:]))  -- No revisit (except start)
    WHERE rs.depth < max_depth
)
SELECT DISTINCT
    (SELECT ARRAY_AGG(m ORDER BY m) FROM UNNEST(rs.path[1:array_length(rs.path,1)-1]) AS m) AS ring_members
FROM ring_search rs
WHERE rs.current_node = rs.start_node  -- Found a cycle
    AND rs.depth >= 3;                 -- Minimum ring size = 3
$$ LANGUAGE SQL STABLE;

-- Calculate fraud score for a member
CREATE OR REPLACE FUNCTION calculate_fraud_score(p_member_id BIGINT, p_community_id BIGINT)
RETURNS TABLE(
    total_score INTEGER,
    reciprocal_voting INTEGER,
    vote_concentration INTEGER,
    ring_participation INTEGER,
    karma_ratio_anomaly INTEGER,
    velocity_anomaly INTEGER,
    factors JSONB
) AS $$
DECLARE
    v_reciprocal INTEGER := 0;
    v_concentration INTEGER := 0;
    v_ring INTEGER := 0;
    v_karma_ratio INTEGER := 0;
    v_velocity INTEGER := 0;
    v_reciprocal_count INTEGER;
    v_herfindahl FLOAT;
    v_ring_count INTEGER;
BEGIN
    -- 1. Reciprocal voting: 10 points per detected pair
    SELECT COUNT(*)
    INTO v_reciprocal_count
    FROM mv_reciprocal_voters
    WHERE (member_a = p_member_id OR member_b = p_member_id)
        AND community_id = p_community_id
        AND reciprocity_ratio > 0.5;
    v_reciprocal := LEAST(v_reciprocal_count * 10, 30);

    -- 2. Vote concentration: Herfindahl index
    SELECT COALESCE(s.herfindahl_index, 0)
    INTO v_herfindahl
    FROM mv_member_vote_stats s
    WHERE s.member_id = p_member_id
        AND s.community_id = p_community_id;
    IF v_herfindahl > 0.5 THEN v_concentration := 30;
    ELSIF v_herfindahl > 0.3 THEN v_concentration := 15;
    END IF;

    -- 3. Ring participation: 20 points per ring
    SELECT COUNT(*)
    INTO v_ring_count
    FROM find_voting_rings(p_community_id) r
    WHERE p_member_id = ANY(r.ring_members);
    v_ring := LEAST(v_ring_count * 20, 40);

    -- 4. Karma ratio anomaly (placeholder — requires karma read model)
    v_karma_ratio := 0;

    -- 5. Velocity anomaly (placeholder — requires time-series analysis)
    v_velocity := 0;

    total_score := LEAST(v_reciprocal + v_concentration + v_ring + v_karma_ratio + v_velocity, 100);
    reciprocal_voting := v_reciprocal;
    vote_concentration := v_concentration;
    ring_participation := v_ring;
    karma_ratio_anomaly := v_karma_ratio;
    velocity_anomaly := v_velocity;
    factors := jsonb_build_object(
        'reciprocal_voting', v_reciprocal,
        'vote_concentration', v_concentration,
        'ring_participation', v_ring,
        'karma_ratio_anomaly', v_karma_ratio,
        'velocity_anomaly', v_velocity
    );
    RETURN NEXT;
END;
$$ LANGUAGE plpgsql STABLE;

COMMIT;
