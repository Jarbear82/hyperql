// ==========================================
// 1. Schema Definitions (DDL)
// ==========================================

DEFINE NAMESPACE Core.Game STRICT_MODE = true;

// 1.1 Enumerations & Structs
DEFINE ENUM PlayerStatus {
    ACTIVE, BANNED, PENDING
};

DEFINE ENUM Gender {
    MALE, FEMALE, OTHER
};

DEFINE STRUCT Vector3 {
    x, y, z
};

// 1.2 Global Field Definitions
// Fields must be defined globally in 0.16
DEFINE FIELD id: UUID @unique @required;
DEFINE FIELD created_at: Date @readonly;
DEFINE FIELD updated_at: Date;
DEFINE FIELD created_by: UUID;
DEFINE FIELD updated_by: UUID;
DEFINE FIELD tags: List<String>;
DEFINE FIELD metadata: String; // Map not supported in 0.16; use JSON String or Struct
DEFINE FIELD position: Vector3;

DEFINE FIELD username: String @index;
DEFINE FIELD score: Int;
DEFINE FIELD status: PlayerStatus;
DEFINE FIELD age: Int;
DEFINE FIELD gender: Gender;
DEFINE FIELD email: String @unique;

// Edge-specific fields (must also be global)
DEFINE FIELD joined_at: Date;
DEFINE FIELD rank: String;
DEFINE FIELD started_at: Date;

// 1.3 Global Role Definitions with Constraints
// Roles define interfaces for WHO can participate in an edge
DEFINE ROLE member_role ALLOWS [Player{ this.status == PlayerStatus.ACTIVE, this.username != ""}];

DEFINE ROLE guild_role ALLOWS [Guild];

DEFINE ROLE friend_role ALLOWS [Player] {
    constraints: [
        Player.age >= 13
    ]
};

DEFINE ROLE quester ALLOWS [Player];
DEFINE ROLE quest_ref ALLOWS [Quest];

DEFINE ROLE leader_role ALLOWS [Player] {
    constraints: {
        is_adult: Player.age >= 18,
        is_active: Player.status == PlayerStatus.ACTIVE
    }
};

// 1.4 Traits & Abstract Nodes
DEFINE TRAIT Timestamped {
    created_at, updated_at
};

DEFINE TRAIT Auditable {
    created_by, updated_by
};

DEFINE ABSTRACT NODE Entity {
    id,
    created_at,
    tags,
    metadata,
    position
};

// 1.5 Concrete Nodes with Constraints
DEFINE NODE Player EXTENDS [Entity] {
    username,
    score,
    status,
    age,
    gender,
    email
} {
    constraints: {
        valid_age: age >= 0 AND age <= 150,
        positive_score: score >= 0,
        has_username: username != ""
    }
};

DEFINE NODE Guild EXTENDS [Entity] {
    // Inherits Entity fields
};

DEFINE NODE Quest EXTENDS [Entity] {
    // Inherits Entity fields
};

// 1.6 Edges with Constraints
// NOTE: In 0.16, grammar requires: Name : Direction Type (Cardinality)
DEFINE EDGE Membership {
    joined_at,
    rank,
    member <- (ONE),
    guild -> (ONE)
} {
    constraints: {
        valid_join_date: joined_at <= NOW(),
        has_rank: rank != ""
    }
};

DEFINE EDGE Friendship {
    created_at,
    friend_a <- friend_role (ONE),
    friend_b -> friend_role (ONE)
} {
    constraints: {
        different_people: friend_a != friend_b,
        valid_date: created_at <= NOW()
    }
};

DEFINE EDGE ActiveQuest {
    started_at,
    player <- quester (ONE),
    quest -> quest_ref (ONE)
} {
    constraints: [
        started_at <= NOW()
    ]
};

DEFINE INDEX idx_player_score ON Player(score);

// ==========================================
// 2. Migration & System
// ==========================================

VALIDATE MIGRATION v1_to_v2 TO v2 MAP {
    old_field: new_field,
    DROP [deprecated_field]
} DEFAULTS {
    new_field: "default_value"
};

// System statements
SHOW NODE TYPES;
EXPLAIN;
ANALYZE;
MATCH (n:Player) RETURN n;

// Transactions
BEGIN ISOLATION LEVEL SERIALIZABLE ON ERROR CONTINUE;

// ... statements ...
COMMIT;

// ==========================================
// 3. Query / Manipulation (DML)
// ==========================================

// Basic Match & Create
MATCH (p:Player { username: "Hero123" })
MATCH (g:Guild { id: "guild-id-placeholder" })
CREATE EDGE e:Membership {
    member => p,           // 0.16 Syntax: Role binding uses '=>'
    guild => g,
    joined_at = NOW(),
    rank = "Member"
};

// Complex Pattern Matching
// Note: Variable length path uses *
MATCH PATH p = (start:City)-[:Road*]->(end:City)
WHERE start.name == "Begin" && end.name != "End"
RETURN p;

// Subqueries & Predicates (EXISTS, IN, ALL, ANY)
MATCH (u:Player)
WHERE EXISTS (
    MATCH (m:Membership { member => u })
    WHERE m.rank == "Leader"
)
AND ANY(tag IN u.tags WHERE tag LIKE "pro%")
RETURN u;

// Path predicates
MATCH PATH p = (a:Player)-[:Friendship*1..3]-(b:Player)
WHERE ALL(node IN p.nodes WHERE node.age >= 18)
  AND NONE(edge IN p.edges WHERE edge.created_at < "2020-01-01")
RETURN p;

// List & Map Literals, Atomic Updates
MATCH (p:Player)
SET p.tags += ["winner"],   // 0.16 Atomic append operator
    p.score = p.score + 100,
    p.metadata = "{ \"level\": 50, \"title\": null }";
// JSON String for metadata

// Atomic remove
MATCH (p:Player)
SET p.tags -= ["beginner"];

// MERGE with ON CREATE / ON MATCH
MERGE (u:Player { id: UUID() })
ON CREATE SET u.created_at = NOW()
ON MATCH SET u.updated_at = NOW();

// Role-based MERGE (requires @unique constraint on roles)
MERGE (e:Membership { member => s, guild => g })
ON CREATE SET e.joined_at = NOW();

// MERGE OBJECT (soft update)
MERGE OBJECT u WITH { score: 150, status: PlayerStatus.ACTIVE };

// ==========================================
// 4. Built-in Functions & Windows
// ==========================================

MATCH (e:Player)
RETURN
    COUNT(e) AS total_players,
    AVG(e.score) AS avg_score,
    MAX(e.score) AS max_score,
    // String functions
    UPPER(e.username),
    CONCAT("Player: ", e.username),
    COALESCE(e.email, "no-email"),
    NULLIF(e.score, 0),
    // Type conversion
    TO_STRING(e.score),
    // Window functions
    RANK() OVER (ORDER BY e.score DESC) AS rank_in_game,
    ROW_NUMBER() OVER (PARTITION BY e.status ORDER BY e.score DESC) AS rank_in_status,
    LAG(e.score) OVER (ORDER BY e.created_at) AS prev_score;

// Graph Algorithms
MATCH (start:Player), (end:Player)
RETURN SHORTEST_PATH(start, end, Friendship) AS path;

// Pathfinding with weights
MATCH PATH p = (a:City)-[:Road* WEIGHT BY distance USING SUM]->(b:City)
RETURN p
ORDER BY p.cost ASC
LIMIT 1;

// Bottleneck path (minimize worst latency)
MATCH PATH p = (a:Server)-[:Link* WEIGHT BY latency USING MAX]->(b:Server)
RETURN p;

// Widest path (maximize minimum bandwidth)
MATCH PATH p = (a:Node)-[:Pipe* WEIGHT BY bandwidth USING MIN]->(b:Node)
RETURN p
ORDER BY p.cost DESC
LIMIT 1;

// ==========================================
// 5. Advanced Logic & Operators
// ==========================================

MATCH (n:Player)
WHERE n.score >= 18
  AND n.status IS NOT NULL
  AND n.username MATCHES "^[A-Z].*"  // Regex match
  AND n.email ILIKE "%@gmail.com"    // Case-insensitive LIKE
RETURN
    CASE
        WHEN n.score > 100 THEN "High"
        WHEN n.score > 50 THEN "Medium"
        ELSE "Low"
    END AS score_category,
    MATCH n.status {
        ACTIVE => "Currently Playing",
        BANNED => "Cannot Play",
        PENDING => "Awaiting Approval",
        _ => "Unknown"
    } AS status_label;

// Null handling
MATCH (p:Player)
WHERE p.email != null
RETURN p.username, COALESCE(p.email, "no-email@example.com");

// OPTIONAL MATCH
MATCH (p:Player)
OPTIONAL MATCH (f:Player)-[:Friendship]-(p)
WHERE f IS NOT NULL
RETURN p.username, COLLECT(f.username) AS friends;

// Delete & Remove
MATCH (n:Player)
DETACH DELETE n;

MATCH (u:Player)
REMOVE u.tags;

// Batch
BATCH {
    CREATE NODE a:Player { id: UUID(), username: "Alice", score: 1, age: 25, status: PlayerStatus.ACTIVE, gender: Gender.FEMALE, email: "alice@example.com" };
    CREATE NODE b:Player { id: UUID(), username: "Bob", score: 2, age: 30, status: PlayerStatus.ACTIVE, gender: Gender.MALE, email: "bob@example.com" };
} RETURN a, b;

// ==========================================
// 6. Aggregation & Grouping
// ==========================================

MATCH (p:Player)
RETURN p.status, COUNT(p) AS player_count, AVG(p.score) AS avg_score
GROUP BY p.status
ORDER BY player_count DESC;

// WITH clause for pipeline
MATCH (p:Player)
WITH p.status AS status, AVG(p.score) AS avg_score
WHERE avg_score > 50
RETURN status, avg_score
ORDER BY avg_score DESC;

// DISTINCT
MATCH (p:Player)
RETURN DISTINCT p.status;

// String aggregation
MATCH (p:Player)
RETURN p.status, STRING_AGG(p.username, ", ") AS usernames
GROUP BY p.status;

// UNION
MATCH (p:Player) WHERE p.score > 100 RETURN p.username
UNION
MATCH (p:Player) WHERE p.age > 50 RETURN p.username;

// UNION ALL (keeps duplicates)
MATCH (p:Player) WHERE p.status == PlayerStatus.ACTIVE RETURN p
UNION ALL
MATCH (p:Player) WHERE p.score > 50 RETURN p;

// UNWIND
UNWIND [1, 2, 3, 4, 5] AS num
RETURN num, num * 2 AS doubled;

// ==========================================
// 7. Cross-Type Queries
// ==========================================

// Global search across all types
MATCH (n) CROSS_TYPE
WHERE n.created_at > "2024-01-01"
RETURN n, TYPE(n);

// Index hints
MATCH (p:Player)
USE INDEX idx_player_score
WHERE p.score > 1000
RETURN p;

// ==========================================
// 8. Complex Constraint Examples
// ==========================================

// Example showing all three constraint levels working together

// Node-level: Validates individual Player entities
DEFINE NODE ValidatedPlayer {
    username,
    age,
    email
} {
    constraints: {
        valid_age: age >= 13 AND age <= 120,
        valid_email: email MATCHES "^[^@]+@[^@]+\\.[^@]+$",
        has_username: username != ""
    }
};

// Role-level: Validates nodes can fill specific roles
DEFINE ROLE adult_member ALLOWS [ValidatedPlayer] {
    constraints: {
        is_adult: ValidatedPlayer.age >= 18
    }
};

// Edge-level: Validates relationships between role-bound nodes
DEFINE EDGE AdultMembership {
    member: <- adult_member (ONE),
    organization: -> guild_role (ONE),
    joined_date: Date
} {
    constraints: {
        valid_join_date: joined_date <= NOW(),
        future_member: member.age < 65
    }
};
