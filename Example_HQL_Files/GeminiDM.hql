/* * ======================================================================================
 * CAMPAIGN KNOWLEDGE BASE: "THE SHATTERED PLANES"
 * HyperQL v0.16 Specification
 * ======================================================================================
 * * This file defines the schema, initial data seed, and analytical queries for a
 * D&D 5e campaign management system.
 * * DESIGN PHILOSOPHY:
 * 1. Strict Schema: Ensures data integrity for mechanics (HP, AC, CR).
 * 2. Hyperedges: Used for complex relationships (Travel, Encounters, Faction Hierarchies).
 * 3. Graph Algorithms: Used to calculate safe travel routes and faction influence.
 */

-- 1. NAMESPACE & CONFIGURATION
-- ======================================================================================
DEFINE NAMESPACE Campaign.ShatteredPlanes STRICT_MODE = true;

-- 2. ENUMERATIONS
-- ======================================================================================
DEFINE ENUM Alignment { LG, NG, CG, LN, N, CN, LE, NE, CE };
DEFINE ENUM Rarity { COMMON, UNCOMMON, RARE, VERY_RARE, LEGENDARY, ARTIFACT };
DEFINE ENUM DamageType { SLASHING, PIERCING, BLUDGEONING, FIRE, COLD, PSYCHIC, NECROTIC, RADIANT };
DEFINE ENUM QuestState { ACTIVE, COMPLETED, FAILED, IGNORED };
DEFINE ENUM Size { TINY, SMALL, MEDIUM, LARGE, HUGE, GARGANTUAN };

-- 3. GLOBAL FIELD DEFINITIONS (Type System)
-- ======================================================================================
-- Basic Identity
DEFINE FIELD ID: UUID @required @unique;
DEFINE FIELD Name: String @required @index(fulltext);
DEFINE FIELD Description: String @index(fulltext) @length(2000);
DEFINE FIELD GMNotes: String @optional;

-- Mechanics
DEFINE FIELD Level: Int;
DEFINE FIELD CR: Float; -- Challenge Rating
DEFINE FIELD AC: Int;
DEFINE FIELD HP: Int;
DEFINE FIELD MaxHP: Int;
DEFINE FIELD Speed: Int;
DEFINE FIELD InitiativeBonus: Int;
DEFINE FIELD IsLegendary: Bool;
DEFINE FIELD Embedding: Vector<384> @index(vector, metric="cosine"); -- For semantic search of lore

-- Economy & Items
DEFINE FIELD GoldValue: Decimal(10, 2);
DEFINE FIELD Weight: Float;
DEFINE FIELD IsMagical: Bool;

-- World
DEFINE FIELD Coordinates: Vector<3>; -- X, Y, Z for 3D mapping
DEFINE FIELD Biome: String;
DEFINE FIELD DangerLevel: Int; -- 1-20 scale
DEFINE FIELD TravelCost: Float; -- Used for pathfinding weights

-- Edge Properties (Extracted)
DEFINE FIELD EncounterChance: Float;
DEFINE FIELD Rank: String;
DEFINE FIELD Renown: Int;
DEFINE FIELD AssignedDate: Date;
DEFINE FIELD DueDate: Date?;
DEFINE FIELD Date: Date;
DEFINE FIELD RoundCount: Int;
DEFINE FIELD Winner: String;
DEFINE FIELD Equipped: Bool;
DEFINE FIELD Quantity: Int;
DEFINE FIELD IsBlocked: Bool;

-- 4. STRUCTS (Value Objects)
-- ======================================================================================
DEFINE STRUCT AbilityScores {
    Str, Dex, Con, Int, Wis, Cha
};

DEFINE STRUCT SaveProficiencies {
    StrSave, DexSave, ConSave, IntSave, WisSave, ChaSave
};

-- 5. ROLES (Interfaces for Edges)
-- ======================================================================================
-- Who can fight?
DEFINE ROLE combatant ALLOWS [PlayerCharacter, NPC, Monster];

-- Who can own items?
DEFINE ROLE inventory_owner ALLOWS [PlayerCharacter, NPC, Container, Location];

-- Who can give/receive quests?
DEFINE ROLE quest_giver ALLOWS [NPC, Faction, Object];
DEFINE ROLE quester ALLOWS [PlayerCharacter, Party];

-- Spatial roles
DEFINE ROLE origin ALLOWS [Location, Region];
DEFINE ROLE destination ALLOWS [Location, Region];
DEFINE ROLE inhabitant ALLOWS [NPC, Monster];

-- Specific Edge Roles
DEFINE ROLE from ALLOWS [Location, Region];
DEFINE ROLE to ALLOWS [Location, Region];
DEFINE ROLE member ALLOWS [NPC, Monster];
DEFINE ROLE organization ALLOWS Faction;
DEFINE ROLE giver ALLOWS [NPC, Faction, Object];
DEFINE ROLE assignee ALLOWS [PlayerCharacter, Party];
DEFINE ROLE objective ALLOWS Quest;
DEFINE ROLE location ALLOWS Location;
DEFINE ROLE party ALLOWS PlayerCharacter;
DEFINE ROLE enemies ALLOWS Monster;
DEFINE ROLE owner ALLOWS [PlayerCharacter, NPC, Container, Location];
DEFINE ROLE item ALLOWS Item;

-- 6. TRAITS (Composable Mixins)
-- ======================================================================================
DEFINE TRAIT StatBlock {
    HP, AC, Speed, InitiativeBonus,
    Abilities: AbilityScores,
    Saves: SaveProficiencies
};

DEFINE TRAIT Locatable {
    Coordinates,
    -- Computed property to format coords for UI
    location_display: String @computed(TO_STRING(this.Coordinates))
};

-- 7. NODE DEFINITIONS
-- ======================================================================================

DEFINE ABSTRACT NODE Entity {
    ID, Name, Description, GMNotes, Embedding
};

-- The Actors
DEFINE NODE PlayerCharacter EXTENDS [Entity, StatBlock, Locatable] {
    Class: String,
    Level,
    PlayerName: String,
    Alignment: Alignment
};

DEFINE NODE NPC EXTENDS [Entity, StatBlock, Locatable] {
    Occupation: String,
    VoiceActorRef: String,
    Alignment: Alignment,
    -- Logic: If HP is low, mark as "Bloodied"
    status_label: String @computed(IF(this.HP < (this.MaxHP / 2), "Bloodied", "Healthy"))
}

DEFINE NODE Monster EXTENDS [Entity, StatBlock, Locatable] {
    CR,
    Size: Size,
    LootTableID: String?,
    IsLegendary
}

-- The World
DEFINE NODE Region EXTENDS [Entity] {
    Biome,
    RecommendedLevel: Int
}

DEFINE NODE Location EXTENDS [Entity, Locatable] {
    IsSafeHaven: Bool,
    Services: List<String>
}

-- Items & Economy
DEFINE NODE Item EXTENDS [Entity] {
    Weight,
    GoldValue,
    Rarity: Rarity,
    IsMagical
}

DEFINE NODE Artifact EXTENDS [Item] {
    Sentience: Bool,
    CurseDescription: String?
}

-- Meta-Game
DEFINE NODE Quest EXTENDS [Entity] {
    Status: QuestState,
    RewardGold: Int,
    XP: Int
}

DEFINE NODE Faction EXTENDS [Entity] {
    Motto: String,
    Influence: Int
}

DEFINE NODE Party EXTENDS [Entity] {
    Reputation: Int
}

-- 8. EDGE DEFINITIONS (Hyperedges)
-- ======================================================================================

-- Travel Routes (Weighted for pathfinding)
DEFINE EDGE Route {
    TravelCost,
    DangerLevel,
    EncounterChance,
    from <- (ONE),
    to -> (ONE)
}

-- Faction Membership (With Rank)
DEFINE EDGE Membership {
    Rank,
    Renown,
    member <- (ONE),
    organization -> (ONE)
} @unique(member, organization) -- Composite constraint

-- Quests (Complex Hyperedge)
-- Connects a Giver, the Party, and the Quest definition
DEFINE EDGE QuestAssignment {
    AssignedDate,
    DueDate,
    giver <- (ONE),
    assignee -> (MANY) @unordered, -- Set semantics
    objective -> (ONE)
};

-- Combat Encounter (The "Session Log")
DEFINE EDGE Encounter {
    Date,
    RoundCount,
    Winner,
    location <- (ONE),
    party <-> (MANY), -- Bidirectional participation
    enemies <-> (MANY)
};

-- Inventory System
DEFINE EDGE Possession {
    Equipped,
    Quantity,
    owner <- (ONE),
    item -> (ONE)
};

-- 9. MIGRATION & SCHEMA UPDATES
-- ======================================================================================
-- Example: We realized we need to track if a route is blocked by weather.
ALTER EDGE Route {
    ADD IsBlocked
}

-- 10. DATA SEEDING (Transactions & Batching)
-- ======================================================================================

-- Create the World Spine
BEGIN;
    CREATE NODE r1:Region { Name = "The Obsidian Wastes", Biome = "Volcanic", RecommendedLevel = 5 };
    CREATE NODE r2:Region { Name = "Silverleaf Forest", Biome = "Forest", RecommendedLevel = 2 };

    CREATE NODE l1:Location {
        Name = "Emberwatch Keep",
        IsSafeHaven = true,
        Coordinates = [10.0, 5.0, 0.0]
    };
    CREATE NODE l2:Location {
        Name = "Spider's Hollow",
        IsSafeHaven = false,
        Coordinates = [12.0, 8.0, -1.0]
    };
COMMIT;

-- Create Routes with "MERGE" to ensure no duplicates
BEGIN;
    MATCH (l1:Location { Name = "Emberwatch Keep" });
    MATCH (l2:Location { Name = "Spider's Hollow" });

    -- Create a dangerous path
    MERGE (r:Route { from => l1, to => l2 })
    ON CREATE SET
        r.TravelCost = 4.0,
        r.DangerLevel = 15,
        r.IsBlocked = false;
COMMIT;

-- Batch Load NPCs (Good for initial campaign setup)
BATCH {
    CREATE NODE n1:NPC { Name = "Gundren Rockseeker", Occupation = "Miner", HP = 20, MaxHP = 20 };
    CREATE NODE n2:NPC { Name = "Sildar Hallwinter", Occupation = "Guard", HP = 35, MaxHP = 35 };
    CREATE NODE f1:Faction { Name = "Lord's Alliance", Influence = 80 };
} RETURN { success, failed, errors };

-- Connect NPC to Faction
BEGIN;
    MATCH (n:NPC { Name = "Sildar Hallwinter" });
    MATCH (f:Faction { Name = "Lord's Alliance" });
    CREATE EDGE m:Membership {
        member => n,
        organization => f,
        Rank = "Agent",
        Renown = 10
    };
COMMIT;

-- 11. DM TOOLS & ANALYTICS (The "Engine")
-- ======================================================================================

/* TOOL A: The "Safe Route" Finder
   Finds a path between locations that minimizes DangerLevel (Bottleneck Path).
   If the party is low level, we want to avoid any edge with high danger.
*/
MATCH (start:Location { Name = "Emberwatch Keep" })
MATCH (end:Location { Name = "Spider's Hollow" })
MATCH PATH p = (start)-[:Route* WEIGHT BY DangerLevel USING MAX]->(end)
RETURN p, p.cost AS max_danger_on_route;

/*
   TOOL B: Global Lore Search (Cross-Type)
   Players ask: "What do we know about 'Vecna'?"
   Searches Items, NPCs, Regions, and Quests simultaneously.
*/
MATCH (n) CROSS_TYPE
USE INDEX DescriptionFulltext -- Query Hint
WHERE n.Description MATCHES ".*Vecna.*"
   OR n.Name LIKE "%Vecna%"
RETURN n.Name, TYPE(n), n.Description;

/*
   TOOL C: Semantic Monster Search (Vector)
   GM needs a monster similar to a "Goblin" but slightly stronger.
   Assumes we have an embedding vector for "Goblin Skirmisher".
*/
MATCH (m:Monster)
WHERE VECTOR_SIMILARITY(m.Embedding, $goblin_vector) > 0.8
  AND m.CR > 1.0 -- Slightly stronger
RETURN m.Name, m.CR, m.HP
ORDER BY VECTOR_SIMILARITY(m.Embedding, $goblin_vector) DESC
LIMIT 5;

/*
   TOOL D: Combat Balance Analyzer (Window Functions)
   Analyze recent encounters to see if the party is struggling (High round counts).
*/
MATCH (e:Encounter)
WHERE e.Date > "2025-01-01"
RETURN e.Date, e.RoundCount,
    AVG(e.RoundCount) OVER (ORDER BY e.Date ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) AS moving_avg_rounds,
    CASE
        WHEN e.RoundCount > 10 THEN "Grind"
        WHEN e.RoundCount < 3 THEN "Stomp"
        ELSE "Balanced"
    END AS combat_feel;

/*
   TOOL E: Faction Influence (Graph Algorithms)
   Calculate which NPCs are most influential based on their connections.
*/
WITH PAGERANK(NPC, Membership) AS influence_scores
MATCH (n:NPC)
WHERE influence_scores[n] > 0.5
RETURN n.Name, influence_scores[n]
ORDER BY influence_scores[n] DESC;

/*
   TOOL F: Inventory Audit (Aggregation)
   Check specifically for legendary items held by the party.
*/
MATCH (pc:PlayerCharacter)
MATCH (pc)<-[:Possession]-(item:Item)
WHERE item.Rarity == .LEGENDARY
RETURN pc.Name,
       COLLECT(item.Name) AS LegendaryItems,
       SUM(item.GoldValue) AS TotalWealth;

-- 12. COMPLEX MUTATION: The "Tpk" (Total Party Kill) Recovery
-- ======================================================================================
/* Scenario: The party died. We need to:
   1. Mark current quests as FAILED.
   2. Move their bodies (Nodes) to the "Graveyard" location.
   3. Unequip all items.
*/

BEGIN;
    -- 1. Fail Quests
    MATCH (q:Quest)<-[:QuestAssignment]-(party:Party)
    WHERE q.Status == .ACTIVE
    SET q.Status = .FAILED;

    -- 2. Move Characters (Update Coordinates)
    MATCH (gy:Location { Name = "Graveyard" });
    MATCH (pc:PlayerCharacter)
    SET pc.Coordinates = gy.Coordinates;

    -- 3. Unequip Items (Update Edge Property)
    MATCH (pc:PlayerCharacter)<-[p:Possession]-(i:Item)
    WHERE p.Equipped == true
    SET p.Equipped = false;
COMMIT;

-- 13. MATERIALIZED PATHS (Performance)
-- ======================================================================================
/*
   For frequently accessed quest chains, we pre-compute the path.
*/
DEFINE FIELD quest_chain: PATH @materialized @computed(TRAVERSE) {
    MATCH PATH p = (this)-[:NextQuest*]->(end:Quest) RETURN p
};

-- 14. SUBQUERY EXAMPLE: "The Prepared GM"
-- ======================================================================================
/* Find random encounters appropriate for the party's current location
   that they haven't fought before.
*/
MATCH (party_loc:Location)<-[:LocatedAt]-(party:Party)
MATCH (m:Monster)
WHERE m.CR <= (MATCH (p:PlayerCharacter) RETURN AVG(p.Level) + 2) -- Subquery for Party Level
  AND m.Biome == party_loc.Biome
  AND NOT EXISTS (
      MATCH (e:Encounter { location => party_loc })
      WHERE m IN e.enemies -- Check if monster type was in previous encounters
  )
RETURN m.Name, m.CR, m.Description
ORDER BY RAND()
LIMIT 1;
