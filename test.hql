// ==========================================
// 1. Schema Definitions (DDL)
// ==========================================

DEFINE NAMESPACE Core.Game STRICT_MODE = true;

// 1.1 Enumerations & Structs
DEFINE ENUM PlayerStatus {
    ACTIVE, BANNED, PENDING
};

DEFINE STRUCT Vector3 {
    x, y, z
};

// 1.2 Global Field Definitions
// Fields must be defined globally in 0.15
DEFINE FIELD id: UUID @unique @required;
DEFINE FIELD created_at: Date @readonly;
DEFINE FIELD updated_at: Date;
DEFINE FIELD created_by: UUID;
DEFINE FIELD updated_by: UUID;

DEFINE FIELD tags: List<String> @optional;
DEFINE FIELD metadata: String; // Map not supported in 0.15; use JSON String or Struct
DEFINE FIELD position: Vector3;

DEFINE FIELD username: String @index;
DEFINE FIELD score: Int; // @default is handled at migration/app level, not schema
DEFINE FIELD status: PlayerStatus;

// Edge-specific fields (must also be global)
DEFINE FIELD joined_at: Date;
DEFINE FIELD rank: String;
DEFINE FIELD started_at: Date;

// 1.3 Global Role Definitions
// Roles define interfaces for WHO can participate in an edge
DEFINE ROLE member_role ALLOWS [Player];
DEFINE ROLE guild_role ALLOWS [Guild];
DEFINE ROLE friend_role ALLOWS [Player];
DEFINE ROLE quester ALLOWS [Player];
DEFINE ROLE quest_ref ALLOWS [Quest];

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

// 1.5 Concrete Nodes
DEFINE NODE Player EXTENDS [Entity] {
    username,
    score,
    status
}

DEFINE NODE Guild EXTENDS [Entity] {
    // Inherits Entity fields
}

DEFINE NODE Quest EXTENDS [Entity] {
    // Inherits Entity fields
}

// 1.6 Edges
DEFINE EDGE Membership {
    joined_at,
    rank,
    member: <- member_role (ONE),
    guild: -> guild_role (ONE)
}

DEFINE EDGE Friendship {
    created_at,
    friend_a: <- friend_role (ONE),
    friend_b: -> friend_role (ONE)
}

DEFINE EDGE ActiveQuest {
    started_at,
    player: <- quester (ONE),
    quest: -> quest_ref (ONE)
}

DEFINE INDEX idx_player_score ON Player(score);

// ==========================================
// 2. Migration & System
// ==========================================

VALIDATE MIGRATION v1_to_v2 TO v2 MAP {
    old_field: new_field,
    DROP [deprecated_field]
} DEFAULTS {
    new_field: "default_value"
}

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
    member -> p,           // 0.15 Syntax: Role assignment uses '->'
    guild -> g,
    joined_at: NOW(),
    rank: "Member"
};

// Complex Pattern Matching
// Note: Variable length path uses *
MATCH PATH p = (start:City)-[:Road*]->(end:City)
WHERE start.name == "Begin" && end.name != "End"
RETURN p;

// Subqueries & Predicates (EXISTS, IN, ALL, ANY)
MATCH (u:Player)
WHERE EXISTS (
    MATCH (u)<-[member_role]-(m:Membership)
    WHERE m.rank == "Leader"
)
// 'scores' is not in schema, assuming meant 'score' or unrelated list
AND ANY(tag IN u.tags WHERE tag LIKE "pro%")
RETURN u;

// List & Map Literals, Atomic Updates
MATCH (p:Player)
SET p.tags = p.tags + ["winner"],   // Explicit list append
    p.score = p.score + 100,
    p.metadata = "{ \"level\": 50, \"title\": null }"; // JSON String for metadata

// MERGE with ON CREATE / ON MATCH
MERGE (u:Player { id: UUID() })
ON CREATE SET u.created_at = NOW()
ON MATCH SET u.updated_at = NOW();

// ==========================================
// 4. Built-in Functions & Windows
// ==========================================

MATCH (e:Player)
RETURN
    count(e) AS total_players,
    avg(e.score) AS avg_score,
    max(e.score) AS max_score,
    // String functions
    UPPER(e.username),
    CONCAT("Player: ", e.username),
    // Window functions
    RANK() OVER (ORDER BY e.score DESC) AS rank_in_game;

// Graph Algorithms (Functional Syntax in 0.15)
MATCH (start:Player), (end:Player)
RETURN SHORTEST_PATH(start, end, Friendship) AS path;

// ==========================================
// 5. Advanced Logic & Operators
// ==========================================

MATCH (n:Player)
WHERE n.score >= 18
  AND (n.status IS NOT NULL)
  AND n.username MATCHES "^[A-Z].*"  // Regex match
RETURN
    CASE
        WHEN n.score > 100 THEN "High"
        WHEN n.score > 50 THEN "Medium"
        ELSE "Low"
    END AS score_category;

// Delete & Remove
MATCH (n:Player)
DETACH DELETE n;

MATCH (u:Player)
SET u.tags = null; // 'REMOVE' replaced with SET null

// Batch
BATCH {
    CREATE NODE a:Player { score: 1 };
    CREATE NODE b:Player { score: 2 };
} RETURN a, b;
