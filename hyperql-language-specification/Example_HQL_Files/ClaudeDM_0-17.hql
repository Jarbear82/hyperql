-- ============================================================================
-- D&D Campaign Knowledge Base - HyperQL v0.16
-- A comprehensive Dungeon Master's campaign management system
-- ============================================================================

DEFINE NAMESPACE Campaign.Realms STRICT_MODE = true;

-- ============================================================================
-- ENUMERATIONS
-- ============================================================================

DEFINE ENUM Alignment {
  LAWFUL_GOOD, NEUTRAL_GOOD, CHAOTIC_GOOD,
  LAWFUL_NEUTRAL, TRUE_NEUTRAL, CHAOTIC_NEUTRAL,
  LAWFUL_EVIL, NEUTRAL_EVIL, CHAOTIC_EVIL
};

DEFINE ENUM CreatureSize {
  TINY, SMALL, MEDIUM, LARGE, HUGE, GARGANTUAN
};

DEFINE ENUM DamageType {
  SLASHING, PIERCING, BLUDGEONING,
  FIRE, COLD, LIGHTNING, THUNDER, ACID, POISON,
  RADIANT, NECROTIC, PSYCHIC, FORCE
};

DEFINE ENUM QuestStatus {
  RUMORED, AVAILABLE, ACTIVE, COMPLETED, FAILED, ABANDONED
};

DEFINE ENUM Rarity {
  COMMON, UNCOMMON, RARE, VERY_RARE, LEGENDARY, ARTIFACT
};

DEFINE ENUM LocationType {
  CITY, TOWN, VILLAGE, DUNGEON, WILDERNESS, TEMPLE, FORTRESS, TAVERN, SHOP
};

DEFINE ENUM FactionReputation {
  HOSTILE, UNFRIENDLY, NEUTRAL, FRIENDLY, ALLIED, EXALTED
};

-- ============================================================================
-- GLOBAL FIELD DEFINITIONS
-- ============================================================================

-- Identity Fields
DEFINE FIELD Id: UUID @readonly;
DEFINE FIELD Name: String @index @required;
DEFINE FIELD Description: String @index(fulltext);
DEFINE FIELD ShortName: String;
DEFINE FIELD Title: String;
DEFINE FIELD Alias: String;

-- Numeric Stats
DEFINE FIELD Level: Int;
DEFINE FIELD HitPoints: Int;
DEFINE FIELD MaxHitPoints: Int;
DEFINE FIELD ArmorClass: Int;
DEFINE FIELD ChallengeRating: Float;
DEFINE FIELD ExperiencePoints: Int;
DEFINE FIELD GoldValue: Int;
DEFINE FIELD Weight: Float;

-- Ability Scores
DEFINE FIELD Strength: Int;
DEFINE FIELD Dexterity: Int;
DEFINE FIELD Constitution: Int;
DEFINE FIELD Intelligence: Int;
DEFINE FIELD Wisdom: Int;
DEFINE FIELD Charisma: Int;

-- Modifiers (computed from ability scores)
DEFINE FIELD StrMod: Int @computed(FLOOR((this.Strength - 10) / 2));
DEFINE FIELD DexMod: Int @computed((this.Dexterity - 10) / 2);
DEFINE FIELD ConMod: Int @computed((this.Constitution - 10) / 2);
DEFINE FIELD IntMod: Int @computed((this.Intelligence - 10) / 2);
DEFINE FIELD WisMod: Int @computed((this.Wisdom - 10) / 2);
DEFINE FIELD ChaMod: Int @computed((this.Charisma - 10) / 2);

-- Enumerated Fields
DEFINE FIELD AlignmentType: Enum<Alignment>;
DEFINE FIELD Size: Enum<CreatureSize>;
DEFINE FIELD Status: Enum<QuestStatus>;
DEFINE FIELD ItemRarity: Enum<Rarity>;
DEFINE FIELD LocType: Enum<LocationType>;
DEFINE FIELD Reputation: Enum<FactionReputation>;

-- Text/Lore Fields
DEFINE FIELD Biography: String;
DEFINE FIELD Motivation: String;
DEFINE FIELD Secret: String;
DEFINE FIELD Rumors: String;
DEFINE FIELD History: String;
DEFINE FIELD Notes: String;
DEFINE FIELD Flavor: String;

-- Metadata
DEFINE FIELD CreatedAt: Date @readonly;
DEFINE FIELD UpdatedAt: Date;
DEFINE FIELD SessionNumber: Int;
DEFINE FIELD IsAlive: Bool;
DEFINE FIELD IsDiscovered: Bool;
DEFINE FIELD IsCompleted: Bool;

-- Location Data
DEFINE FIELD Latitude: Float;
DEFINE FIELD Longitude: Float;
DEFINE FIELD Population: Int;
DEFINE FIELD MapReference: String;

-- Special Properties
DEFINE FIELD MagicBonus: Int;
DEFINE FIELD AttunementRequired: Bool;
DEFINE FIELD Charges: Int?;
DEFINE FIELD MaxCharges: Int?;
DEFINE FIELD DamageTypeProp: Enum<DamageType>;

-- Edge Properties (Extracted)
DEFINE FIELD quantity: Int;
DEFINE FIELD IsEquipped: Bool;
DEFINE FIELD subject: String;
DEFINE FIELD initiative: Int;
DEFINE FIELD distance: Float;
DEFINE FIELD danger: Int;
DEFINE FIELD participation_role: String;
DEFINE FIELD information: String;

-- Computed Display Names
DEFINE FIELD DisplayName: String @computed(
  IF(this.Title != null, this.Title + " " + this.Name, this.Name)
) @display;

-- Vector Embeddings for Semantic Search
DEFINE FIELD DescriptionEmbedding: Vector<384> @index(vector, metric="cosine");
DEFINE FIELD LoreEmbedding: Vector<384> @index(vector, metric="cosine");

-- ============================================================================
-- ROLES - Define relationship endpoints
-- ============================================================================

-- General Roles
DEFINE ROLE character ALLOWS [PlayerCharacter, NonPlayerCharacter, Creature];
DEFINE ROLE combatant ALLOWS [PlayerCharacter, NonPlayerCharacter, Creature];
DEFINE ROLE quest_giver ALLOWS [NonPlayerCharacter, Faction, Deity];
DEFINE ROLE quest_target ALLOWS [NonPlayerCharacter, Creature, Location, Item];
DEFINE ROLE merchant ALLOWS [NonPlayerCharacter];
DEFINE ROLE customer ALLOWS [PlayerCharacter, NonPlayerCharacter];
DEFINE ROLE owner ALLOWS [PlayerCharacter, NonPlayerCharacter, Faction];
DEFINE ROLE possessor ALLOWS [PlayerCharacter, NonPlayerCharacter, Creature, Location];
DEFINE ROLE member ALLOWS [PlayerCharacter, NonPlayerCharacter];
DEFINE ROLE organization ALLOWS [Faction, Guild];
DEFINE ROLE parent ALLOWS [Location];
DEFINE ROLE child ALLOWS [Location];
DEFINE ROLE worshipper ALLOWS [PlayerCharacter, NonPlayerCharacter, Faction];
DEFINE ROLE divine ALLOWS [Deity];
DEFINE ROLE teacher ALLOWS [NonPlayerCharacter];
DEFINE ROLE student ALLOWS [PlayerCharacter, NonPlayerCharacter];
DEFINE ROLE source ALLOWS [Location, NonPlayerCharacter, Event];
DEFINE ROLE destination ALLOWS [Location];
DEFINE ROLE participant ALLOWS [PlayerCharacter, NonPlayerCharacter, Creature];
DEFINE ROLE scene ALLOWS [Event, Encounter];

-- Specific Edge Roles
DEFINE ROLE party ALLOWS PlayerCharacter;
DEFINE ROLE character1 ALLOWS [PlayerCharacter, NonPlayerCharacter, Creature];
DEFINE ROLE character2 ALLOWS [PlayerCharacter, NonPlayerCharacter, Creature];
DEFINE ROLE giver ALLOWS [NonPlayerCharacter, Faction, Deity];
DEFINE ROLE quest ALLOWS Quest;
DEFINE ROLE recipient ALLOWS [PlayerCharacter, NonPlayerCharacter, Creature];
DEFINE ROLE target ALLOWS [NonPlayerCharacter, Creature, Location, Item];
DEFINE ROLE item ALLOWS Item;
DEFINE ROLE deity ALLOWS Deity;
DEFINE ROLE encounter ALLOWS [Event, Encounter];
DEFINE ROLE event ALLOWS [Event, Encounter];
DEFINE ROLE knower ALLOWS [PlayerCharacter, NonPlayerCharacter, Creature];
DEFINE ROLE known ALLOWS Entity;
DEFINE ROLE caster ALLOWS [PlayerCharacter, NonPlayerCharacter, Creature];
DEFINE ROLE spell ALLOWS Spell;

-- ============================================================================
-- TRAITS - Composable interfaces
-- ============================================================================

DEFINE TRAIT Identifiable {
  Id,
  Name,
  Description,
  CreatedAt,
  UpdatedAt
};

DEFINE TRAIT HasStats {
  Strength,
  Dexterity,
  Constitution,
  Intelligence,
  Wisdom,
  Charisma,
  StrMod,
  DexMod,
  ConMod,
  IntMod,
  WisMod,
  ChaMod
};

DEFINE TRAIT Combative {
  HitPoints,
  MaxHitPoints,
  ArmorClass,
  IsAlive
};

DEFINE TRAIT Positioned {
  Latitude,
  Longitude,
  MapReference
};

DEFINE TRAIT Discoverable {
  IsDiscovered,
  Rumors
};

-- ============================================================================
-- NODE TYPES
-- ============================================================================

DEFINE ABSTRACT NODE Entity EXTENDS [Identifiable] {
  Id,
  Name,
  Description,
  CreatedAt,
  UpdatedAt,
  Notes
};

-- Characters
DEFINE NODE PlayerCharacter EXTENDS [Entity, HasStats, Combative] {
  Id,
  Name,
  Description,
  CreatedAt,
  UpdatedAt,
  Notes,
  Strength,
  Dexterity,
  Constitution,
  Intelligence,
  Wisdom,
  Charisma,
  StrMod,
  DexMod,
  ConMod,
  IntMod,
  WisMod,
  ChaMod,
  HitPoints,
  MaxHitPoints,
  ArmorClass,
  IsAlive,
  Level,
  ExperiencePoints,
  AlignmentType,
  Biography,
  DisplayName
};

DEFINE NODE NonPlayerCharacter EXTENDS [Entity, HasStats, Combative, Discoverable] {
  Id,
  Name,
  Description,
  CreatedAt,
  UpdatedAt,
  Notes,
  Strength,
  Dexterity,
  Constitution,
  Intelligence,
  Wisdom,
  Charisma,
  StrMod,
  DexMod,
  ConMod,
  IntMod,
  WisMod,
  ChaMod,
  HitPoints,
  MaxHitPoints,
  ArmorClass,
  IsAlive,
  Level,
  AlignmentType,
  Biography,
  Motivation,
  Secret,
  IsDiscovered,
  Rumors,
  DisplayName
};

DEFINE NODE Creature EXTENDS [Entity, Combative] {
  Id,
  Name,
  Description,
  CreatedAt,
  UpdatedAt,
  Notes,
  HitPoints,
  MaxHitPoints,
  ArmorClass,
  IsAlive,
  Size,
  ChallengeRating,
  AlignmentType
};

-- World Entities
DEFINE NODE Location EXTENDS [Entity, Positioned, Discoverable] {
  Id,
  Name,
  Description,
  CreatedAt,
  UpdatedAt,
  Notes,
  Latitude,
  Longitude,
  MapReference,
  IsDiscovered,
  Rumors,
  LocType,
  Population,
  History
};

DEFINE NODE Item EXTENDS [Entity, Discoverable] {
  Id,
  Name,
  Description,
  CreatedAt,
  UpdatedAt,
  Notes,
  IsDiscovered,
  Rumors,
  ItemRarity,
  GoldValue,
  Weight,
  MagicBonus,
  AttunementRequired,
  Charges,
  MaxCharges
};

DEFINE NODE Quest EXTENDS [Entity] {
  Id,
  Name,
  Description,
  CreatedAt,
  UpdatedAt,
  Notes,
  Status,
  ExperiencePoints,
  GoldValue,
  SessionNumber
};

DEFINE NODE Faction EXTENDS [Entity] {
  Id,
  Name,
  Description,
  CreatedAt,
  UpdatedAt,
  Notes,
  AlignmentType,
  History
};

DEFINE NODE Guild EXTENDS [Entity] {
  Id,
  Name,
  Description,
  CreatedAt,
  UpdatedAt,
  Notes,
  History
};

DEFINE NODE Deity EXTENDS [Entity] {
  Id,
  Name,
  Description,
  CreatedAt,
  UpdatedAt,
  Notes,
  Title,
  AlignmentType,
  History
};

DEFINE NODE Event EXTENDS [Entity] {
  Id,
  Name,
  Description,
  CreatedAt,
  UpdatedAt,
  Notes,
  SessionNumber,
  IsCompleted
};

DEFINE NODE Encounter EXTENDS [Entity] {
  Id,
  Name,
  Description,
  CreatedAt,
  UpdatedAt,
  Notes,
  SessionNumber,
  ChallengeRating,
  IsCompleted
};

DEFINE NODE Spell EXTENDS [Entity] {
  Id,
  Name,
  Description,
  CreatedAt,
  UpdatedAt,
  Notes,
  Level
};

-- ============================================================================
-- STRUCTS - Embedded value objects
-- ============================================================================

DEFINE STRUCT AbilityCheck {
  Name,
  DamageTypeProp,
  Description
};

DEFINE STRUCT Coordinates {
  Latitude,
  Longitude
};

-- ============================================================================
-- EDGE TYPES - Relationships with roles
-- ============================================================================

-- Party Membership
DEFINE EDGE PartyMembership {
  member <- (ONE),
  party -> (MANY) @ordered,
  SessionNumber
} @unique(member);

-- Friendship/Rivalry
DEFINE EDGE Relationship {
  character1 <- (ONE),
  character2 -> (ONE),
  Description,
  Reputation
} @unique(character1, character2);

-- Quest Assignment
DEFINE EDGE QuestAssignment {
  giver <- (ONE),
  quest -> (ONE),
  recipient -> (MANY) @ordered,
  SessionNumber
} @unique(quest);

-- Quest Objectives
DEFINE EDGE QuestObjective {
  quest <- (ONE),
  target -> (MANY) @unordered,
  Description,
  IsCompleted
};

-- Inventory/Possession
DEFINE EDGE Possession {
  owner <- (ONE),
  item -> (MANY) @ordered,
  quantity,
  IsEquipped,
  SessionNumber
};

-- Trade Transaction
DEFINE EDGE Transaction {
  merchant <- (ONE),
  customer -> (ONE),
  item -> (ONE),
  GoldValue,
  SessionNumber,
  CreatedAt
} @unique(merchant, customer, item, CreatedAt);

-- Faction Membership
DEFINE EDGE Membership {
  member <- (ONE),
  organization -> (ONE),
  Reputation,
  SessionNumber
} @unique(member, organization);

-- Location Containment
DEFINE EDGE LocationContainment {
  parent <- (ONE),
  child -> (MANY) @ordered,
  Description
};

-- Worship/Divine Connection
DEFINE EDGE Worship {
  worshipper <- (ONE),
  deity -> (ONE),
  Reputation,
  Description
} @unique(worshipper, deity);

-- Knowledge/Training
DEFINE EDGE Training {
  teacher <- (ONE),
  student -> (MANY) @ordered,
  subject,
  SessionNumber,
  IsCompleted
};

-- Combat Encounter
DEFINE EDGE CombatParticipation {
  encounter <- (ONE),
  combatant -> (MANY) @ordered,
  initiative,
  IsAlive,
  SessionNumber
};

-- Travel Routes
DEFINE EDGE TravelRoute {
  source <- (ONE),
  destination -> (ONE),
  distance,
  danger,
  Description
} @unique(source, destination);

-- Event Participation
DEFINE EDGE EventParticipation {
  event <- (ONE),
  participant -> (MANY) @unordered,
  participation_role,
  SessionNumber
};

-- Knowledge Connection (who knows what about whom)
DEFINE EDGE Knowledge {
  knower <- (ONE),
  known -> (MANY) @unordered,
  information,
  SessionNumber
};

-- Spell Casting Ability
DEFINE EDGE SpellKnowledge {
  caster <- (ONE),
  spell -> (MANY) @ordered,
  SessionNumber
};

-- ============================================================================
-- INDEXES
-- ============================================================================

DEFINE INDEX CharacterNameIndex ON PlayerCharacter (Name);
DEFINE INDEX NPCNameAlignmentIndex ON NonPlayerCharacter (Name, AlignmentType);
DEFINE INDEX LocationTypeIndex ON Location (LocType, IsDiscovered);
DEFINE INDEX QuestStatusIndex ON Quest (Status, SessionNumber);
DEFINE INDEX ItemRarityIndex ON Item (ItemRarity, GoldValue);
DEFINE INDEX EncounterSessionIndex ON Encounter (SessionNumber, IsCompleted);

-- ============================================================================
-- SAMPLE DATA & QUERIES
-- ============================================================================

-- Create the adventuring party
CREATE NODE aragorn:PlayerCharacter {
  Id = UUID(),
  Name = "Aragorn Stormblade",
  Description = "A human ranger with a mysterious past",
  CreatedAt = NOW(),
  UpdatedAt = NOW(),
  Strength = 16,
  Dexterity = 14,
  Constitution = 15,
  Intelligence = 10,
  Wisdom = 13,
  Charisma = 12,
  HitPoints = 45,
  MaxHitPoints = 45,
  ArmorClass = 16,
  IsAlive = true,
  Level = 5,
  ExperiencePoints = 6500,
  AlignmentType = .NEUTRAL_GOOD,
  Biography = "Once a soldier in the King's army, now seeks redemption",
  Notes = "Party leader, tends to be cautious"
};

CREATE NODE lyra:PlayerCharacter {
  Id = UUID(),
  Name = "Lyra Moonwhisper",
  Description = "An elven wizard specializing in divination magic",
  CreatedAt = NOW(),
  UpdatedAt = NOW(),
  Strength = 8,
  Dexterity = 14,
  Constitution = 12,
  Intelligence = 18,
  Wisdom = 14,
  Charisma = 10,
  HitPoints = 28,
  MaxHitPoints = 28,
  ArmorClass = 12,
  IsAlive = true,
  Level = 5,
  ExperiencePoints = 6500,
  AlignmentType = .CHAOTIC_GOOD,
  Biography = "Exiled from her forest home for dabbling in forbidden magic",
  Notes = "Curious about ancient artifacts, sometimes reckless"
};

-- Create important NPCs
CREATE NODE elder_theron:NonPlayerCharacter {
  Id = UUID(),
  Name = "Theron the Wise",
  Description = "Village elder with knowledge of ancient prophecies",
  CreatedAt = NOW(),
  UpdatedAt = NOW(),
  Strength = 8,
  Dexterity = 10,
  Constitution = 12,
  Intelligence = 16,
  Wisdom = 18,
  Charisma = 14,
  HitPoints = 22,
  MaxHitPoints = 22,
  ArmorClass = 10,
  IsAlive = true,
  Level = 7,
  AlignmentType = .LAWFUL_GOOD,
  Biography = "Has served as village elder for over 40 years",
  Motivation = "Protect the village and preserve ancient knowledge",
  Secret = "Knows the location of the Shadow Temple but fears its power",
  IsDiscovered = true,
  Rumors = "Some say he can see the future in his dreams"
};

CREATE NODE villain_malachar:NonPlayerCharacter {
  Id = UUID(),
  Name = "Malachar the Defiler",
  Description = "Dark sorcerer seeking to awaken an ancient evil",
  CreatedAt = NOW(),
  UpdatedAt = NOW(),
  Strength = 12,
  Dexterity = 14,
  Constitution = 14,
  Intelligence = 20,
  Wisdom = 16,
  Charisma = 18,
  HitPoints = 85,
  MaxHitPoints = 85,
  ArmorClass = 15,
  IsAlive = true,
  Level = 12,
  AlignmentType = .CHAOTIC_EVIL,
  Biography = "Once a promising apprentice, corrupted by forbidden texts",
  Motivation = "Believes awakening the Dark God will grant him immortality",
  Secret = "His sister is imprisoned in the Shadow Realm",
  IsDiscovered = true,
  Rumors = "Whispers speak of his unholy pact with demons"
};

-- Create locations
CREATE NODE village_haven:Location {
  Id = UUID(),
  Name = "Millhaven",
  Description = "A peaceful farming village nestled in a verdant valley",
  CreatedAt = NOW(),
  UpdatedAt = NOW(),
  Latitude = 42.5,
  Longitude = -71.3,
  LocType = .VILLAGE,
  Population = 450,
  IsDiscovered = true,
  History = "Founded 200 years ago by refugees fleeing the Dragon Wars",
  Rumors = "Strange lights have been seen in the nearby forest at night"
};

CREATE NODE dungeon_shadow:Location {
  Id = UUID(),
  Name = "Shadow Temple",
  Description = "Ancient temple corrupted by dark magic, sealed for centuries",
  CreatedAt = NOW(),
  UpdatedAt = NOW(),
  Latitude = 42.8,
  Longitude = -71.5,
  LocType = .TEMPLE,
  IsDiscovered = false,
  History = "Built to honor the Sun God, later defiled by necromancers",
  Rumors = "Those who enter are said to never return the same"
};

-- Create items
CREATE NODE sword_flame:Item {
  Id = UUID(),
  Name = "Flamebrand",
  Description = "A longsword wreathed in eternal flames",
  CreatedAt = NOW(),
  UpdatedAt = NOW(),
  ItemRarity = .RARE,
  GoldValue = 5000,
  Weight = 3.0,
  MagicBonus = 2,
  AttunementRequired = true,
  IsDiscovered = true,
  Rumors = "Forged in dragon fire by the legendary smith Thane Ironfist"
};

-- Create factions
CREATE NODE faction_order:Faction {
  Id = UUID(),
  Name = "Order of the Silver Dawn",
  Description = "Paladins dedicated to fighting undead and dark magic",
  CreatedAt = NOW(),
  UpdatedAt = NOW(),
  AlignmentType = .LAWFUL_GOOD,
  History = "Founded after the Necromancer Wars to prevent such darkness from rising again"
};

-- Create quests
CREATE NODE quest_temple:Quest {
  Id = UUID(),
  Name = "Cleanse the Shadow Temple",
  Description = "Investigate and purify the corrupted temple before the dark ritual is completed",
  CreatedAt = NOW(),
  UpdatedAt = NOW(),
  Status = .ACTIVE,
  ExperiencePoints = 2000,
  GoldValue = 500,
  SessionNumber = 3
};

-- Create deities
CREATE NODE deity_sun:Deity {
  Id = UUID(),
  Name = "Solara",
  Title = "The Radiant Dawn",
  Description = "Goddess of light, healing, and protection",
  CreatedAt = NOW(),
  UpdatedAt = NOW(),
  AlignmentType = .NEUTRAL_GOOD,
  History = "Worshipped since the dawn of civilization, opposed to undeath"
};

-- Create relationships
CREATE EDGE party_rel:PartyMembership {
  member => aragorn,
  party => [aragorn, lyra],
  SessionNumber = 1
};

CREATE EDGE quest_assignment:QuestAssignment {
  giver => elder_theron,
  quest => quest_temple,
  recipient => [aragorn, lyra],
  SessionNumber = 3
};

CREATE EDGE quest_obj:QuestObjective {
  quest => quest_temple,
  target => [dungeon_shadow, villain_malachar],
  Description = "Stop Malachar from completing the dark ritual",
  IsCompleted = false
};

CREATE EDGE possess_sword:Possession {
  owner => aragorn,
  item => [sword_flame],
  quantity = 1,
  IsEquipped = true,
  SessionNumber = 2
};

CREATE EDGE faction_member:Membership {
  member => aragorn,
  organization => faction_order,
  Reputation = .FRIENDLY,
  SessionNumber = 1
};

CREATE EDGE worship_rel:Worship {
  worshipper => aragorn,
  deity => deity_sun,
  Reputation = .ALLIED,
  Description = "Devoted follower who prays daily"
};

CREATE EDGE location_contain:LocationContainment {
  parent => village_haven,
  child => [dungeon_shadow],
  Description = "The temple lies 5 miles north of the village"
};

CREATE EDGE travel_path:TravelRoute {
  source => village_haven,
  destination => dungeon_shadow,
  distance = 5.0,
  danger = 8,
  Description = "Forest path, haunted by undead at night"
};

-- ============================================================================
-- EXAMPLE QUERIES FOR DM USE
-- ============================================================================

-- Query 1: Find all active quests with their objectives
MATCH (q:Quest)
WHERE q.Status == .ACTIVE
OPTIONAL MATCH (obj:QuestObjective { quest => q })
RETURN q.Name, q.Description,
  COLLECT(obj.Description) AS objectives,
  q.ExperiencePoints,
  q.GoldValue
ORDER BY q.SessionNumber DESC;

-- Query 2: Get party roster with current HP percentage
MATCH (p:PlayerCharacter)
WHERE p.IsAlive == true
RETURN p.Name,
  p.Level,
  p.HitPoints,
  p.MaxHitPoints,
  (p.HitPoints * 100.0 / p.MaxHitPoints) AS hp_percentage,
  p.ArmorClass
ORDER BY p.Name;

-- Query 3: Find NPCs by alignment and their relationships to party
MATCH (n:NonPlayerCharacter)
WHERE n.AlignmentType == .CHAOTIC_EVIL
  AND n.IsAlive == true
OPTIONAL MATCH (r:Relationship { character1 => n })
RETURN n.Name,
  n.Description,
  n.Level,
  n.Secret,
  COUNT(r) AS known_relationships
ORDER BY n.Level DESC;

-- Query 4: Discover nearby locations from a starting point
MATCH (start:Location { Name = "Millhaven" })
MATCH (route:TravelRoute { source => start })
MATCH (dest:Location)
WHERE route.destination == dest
RETURN dest.Name,
  dest.LocType,
  route.distance,
  route.danger,
  dest.IsDiscovered,
  dest.Rumors
ORDER BY route.distance ASC;

-- Query 5: Party inventory summary with total value
MATCH (pc:PlayerCharacter)
WHERE pc.IsAlive == true
MATCH (inv:Possession { owner => pc })
MATCH (i:Item)
WHERE inv.item CONTAINS i
RETURN pc.Name AS character,
  i.Name AS item,
  i.ItemRarity AS rarity,
  i.GoldValue AS value,
  inv.IsEquipped AS equipped
ORDER BY pc.Name, i.GoldValue DESC;

-- Query 6: Find all magical items not yet discovered
MATCH (i:Item)
WHERE i.IsDiscovered == false
  AND i.MagicBonus > 0
RETURN i.Name,
  i.ItemRarity,
  i.Description,
  i.Rumors
ORDER BY i.ItemRarity DESC;

-- Query 7: Faction reputation report
MATCH (pc:PlayerCharacter)
MATCH (mem:Membership { member => pc })
MATCH (f:Faction)
WHERE mem.organization == f
RETURN pc.Name AS character,
  f.Name AS faction,
  mem.Reputation AS standing
ORDER BY pc.Name, f.Name;

-- Query 8: Session timeline of events
MATCH (e:Event)
WHERE e.SessionNumber <= 5
RETURN e.SessionNumber,
  e.Name,
  e.Description,
  e.IsCompleted
ORDER BY e.SessionNumber DESC, e.CreatedAt DESC;

-- Query 9: Find shortest travel path between locations
MATCH PATH p = (start:Location { Name = "Millhaven" })-[:TravelRoute* WEIGHT BY distance USING SUM]->(end:Location { Name = "Shadow Temple" })
RETURN p.nodes AS path_locations,
  p.cost AS total_distance,
  p.length AS number_of_stops
ORDER BY p.cost ASC
LIMIT 1;

-- Query 10: Complex query - Find quest chains (quests that lead to other quests)
MATCH (q1:Quest)
MATCH (obj:QuestObjective { quest => q1 })
MATCH (target:Location)
WHERE obj.target CONTAINS target
MATCH (q2:Quest)
MATCH (obj2:QuestObjective { quest => q2 })
WHERE obj2.target CONTAINS target
  AND q1.Id != q2.Id
RETURN q1.Name AS prerequisite_quest,
  target.Name AS shared_location,
  q2.Name AS subsequent_quest,
  q1.Status AS prereq_status,
  q2.Status AS next_status
ORDER BY q1.SessionNumber, q2.SessionNumber;

-- Query 11: Advanced - Character power level analysis with window functions
MATCH (c:Character)
RETURN c.Name,
  c.Level,
  c.MaxHitPoints,
  c.ArmorClass,
  RANK() OVER (ORDER BY c.Level DESC) AS level_rank,
  AVG(c.Level) OVER () AS avg_party_level,
  c.Level - AVG(c.Level) OVER () AS level_difference
ORDER BY c.Level DESC;

-- Query 12: Find all knowledge connections (what characters know about the villain)
MATCH (know:Knowledge)
MATCH (villain:NonPlayerCharacter { Name = "Malachar the Defiler" })
WHERE know.known CONTAINS villain
MATCH (knower:Character)
WHERE know.knower == knower
RETURN knower.Name,
  know.information,
  know.SessionNumber
ORDER BY know.SessionNumber DESC;
