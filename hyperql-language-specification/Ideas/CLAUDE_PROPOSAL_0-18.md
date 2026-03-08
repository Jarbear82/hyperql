# HyperQL v0.18 — Language Proposal (Updated)
**Status:** Draft  
**Based on:** v0.17 spec + v0.18 design discussion + multi-reviewer analysis + DOD architecture review  
**Scope:** Storage architecture specification, typed enums, field/edge/node defaults, extended
cardinality, batch/multi-syntax, namespace modularization, unified syntax model, query block
syntax, `@cold` decorator, materialized views

---

## Overview

v0.18 introduces changes across two categories. All v0.17 schemas and queries remain valid
without modification.

**Language Features (additive):**
1. **Typed Enums** — `<TYPE>` parameter enabling integer-backed, decimal-backed, string-backed,
   and bitfield (FLAGS) variants
2. **Field, Edge, and Node Defaults** — `DEFAULT` clause for write-time default values, applied
   symmetrically to global field definitions, edge field definitions, and node field definitions
3. **Extended Cardinality** — exact counts and ranges replace the binary `ONE`/`MANY` system,
   deprecating the `?` role suffix, with full mutation enforcement
4. **Batch / Multi-Syntax** — `[...]` block form for all definition and mutation statements
5. **Namespace Modularization** — dot-hierarchy namespace naming for multi-file schema
   organization
6. **Query Block Syntax** — consistent `[...]` block form extended to query clauses
7. **`@cold` Decorator** — explicit secondary-partition placement for large, infrequently-
   accessed fields

**Storage Architecture (normative):**
8. **Data-Oriented Storage Model** — explicit physical storage specification covering column
   layout, struct inlining, null bitmaps, role index tables, SIMD alignment, and materialized
   views

The storage architecture section is **normative** for all compliant implementations. It
specifies the physical model that the language's performance guarantees depend on.

---

## Unified Syntax Model

Before the individual features, this section defines the syntactic grammar that underpins
all v0.18 additions. Every new form is an instance of this single model.

### Grammar

```
Statement  = Keyword Block? Block? ;
Block      = [ Entry, Entry, ... ]     -- array block, comma-separated
           | { Key: Value, ... }       -- struct block, comma-separated
Entry      = Statement | Expression | Name
```

### Rules

- `,` separates entries within `[...]` or `{...}` blocks. Trailing commas are allowed.
- `;` terminates a complete statement.
- Whitespace is cosmetically optional. Removing all whitespace must leave an unambiguous
  token stream. This is a hard requirement for all v0.18 syntax additions.
- `[` `]` are balanced array delimiters. `{` `}` are balanced struct delimiters. Nesting
  is always unambiguous because delimiters are balanced, not whitespace-dependent.
- A single-statement form is semantically equivalent to a batch block with one entry and
  brackets elided. The two forms compile to identical ASTs.

```hql
DEFINE FIELD id: UUID;         -- single form
DEFINE FIELD [ id: UUID ];     -- batch form, one entry — identical AST
```

### Parser Simplification Guarantee

The `[...]` block syntax is not only a readability improvement — it is a **tokenizer
correctness property**. Balanced delimiters (`[`, `]`, `{`, `}`) enable unambiguous
tokenization without whitespace heuristics. This means:

- The tokenizer never needs context to determine block boundaries
- Whitespace can be stripped entirely and the token stream remains unambiguous
- Formatters, minifiers, and static analyzers can make reliable transformations without
  executing the full parser
- Embedded HyperQL (in IDEs, query builders, or host languages) does not require
  whitespace-aware parsing

This property is verified by the whitespace-free readability guarantee applied to every
new syntax form in this proposal.

### Hoisting and Validation Order

Within any `DEFINE [...]` block or schema file, all names are collected before any
references are resolved. Definition order does not affect validity. This is the hoisting
guarantee.

Validation proceeds in five passes across the entire file or block:

```
Pass 1 — Collection:    Register all names (ENUM, FIELD, STRUCT, TRAIT, ROLE, NODE, EDGE,
                        FUNCTION, INDEX)
Pass 2 — Type checking: Resolve all type references (field types, ALLOWS types, EXTENDS)
Pass 3 — Constraints:   Validate constraint expressions against resolved types
Pass 4 — Edges:         Validate role references in DEFINE EDGE
Pass 5 — Indexes:       Validate DEFINE INDEX targets against resolved node types
```

Each pass proceeds only if the previous pass produced zero errors. This prevents error
cascades — a single misspelled type in Pass 2 does not produce dozens of downstream
errors in Pass 3.

---

## 0. Storage Architecture

This section is **normative**. All compliant HyperQL implementations must satisfy these
storage model requirements. Query performance guarantees stated elsewhere in this spec
depend on this physical model.

### 0.1 Hybrid Column/Row Storage Model

Within a type partition, storage is organized as follows:

**Fixed-width fields** — `Int`, `Int32`, `Float`, `Bool`, `Date`, `UUID`, `Decimal(P,S)`,
`Enum<T>`, `Flags<T>`, `Vector<N>` — are stored **column-oriented**: one contiguous array
per field across all rows in the partition.

**Variable-width fields** — `String`, `List<T>` — are stored in a **variable-length heap**
separate from the column store. The column store holds fixed-width offset/length pairs
pointing into the heap. Filtering operations never access the heap; projection operations do.

```
Person Type Partition

Column Store (fixed-width, one array per field):
  id:         [ UUID, UUID, UUID, ... ]         -- 16 bytes per row
  age:        [ Int,  Int,  Int,  ... ]         -- 8 bytes per row
  status:     [ Enum, Enum, Enum, ... ]         -- varies by backing type
  name_ptr:   [ (offset, len), (offset, len) ]  -- 12 bytes per row → heap

Variable-Length Heap:
  [ "Alice\0Bob\0Carol\0..." ]                  -- packed strings
```

**Late Materialization:** The query optimizer must delay loading variable-width fields and
`@cold` partition fields until after all filter predicates have been applied. Heap access
occurs only for rows that survive predicate evaluation.

**Consequences for queries:**
- `WHERE p.age > 30` reads only the `age` column array. No other field is loaded.
- `WHERE p.name LIKE "A%"` reads `name_ptr` offsets and accesses the heap only for
  candidate rows after position filtering.
- `RETURN p.id, p.name` reads two columns and the heap for projected rows only.
- `RETURN p` reads all columns and all heap references for projected rows.

### 0.2 Struct Inline Storage Guarantee

Struct fields are stored **physically inline** within the containing node's column store.
No heap allocation or pointer indirection occurs for Struct access.

```hql
DEFINE STRUCT Address { Street, City, ZipCode }
DEFINE NODE Person { home: Struct<Address>, work: Struct<Address>? }
```

`Person.home` is stored as inline column entries (`home.Street_ptr`, `home.City_ptr`,
`home.ZipCode_ptr`) within the Person partition. Accessing `p.home.City` requires no
pointer dereference beyond a normal column store lookup.

A nullable Struct (`Struct<Address>?`) stores a null bit in the null bitmap (see §0.3)
and leaves the struct's column slots zeroed. No separate allocation occurs for null struct
values.

**This guarantee is the defining property of Structs relative to Nodes.** A Struct that
required pointer indirection would provide no data locality benefit over a connected Node.

### 0.3 Null Bitmap Representation

Each type partition maintains a **null bitmap** — one bit per nullable field per row,
stored as a contiguous bit vector in the column-oriented layout.

Null-checking operations (`IS NULL`, `IS NOT NULL`, `??`, `?.`, `== null`, `!= null`)
consult only the null bitmap. They never access field storage for null rows.

**Properties:**
- Null checks are O(1) bit operations regardless of field type or size
- A null `String?` stores nothing in the variable-length heap
- A null `Struct<Address>?` stores nothing beyond its null bit
- A null `Vector<384>?` occupies no aligned storage beyond its null bit

### 0.4 MANY Role Storage Model

The `@ordered`/`@unordered` semantic distinction maps to distinct physical structures:

| Decorator | Physical Structure | Membership Test | Index Access | Insertion |
|---|---|---|---|---|
| `@ordered` (default) | Dynamic array | O(n) scan | O(1) by position | O(1) amortized |
| `@unordered` | Open-addressing hash set | O(1) average | Not supported | O(1) amortized |

Extended cardinality bounds (§3) inform initial allocation strategy:

| Cardinality | Allocation Strategy |
|---|---|
| `(1)` | Single slot, no array overhead |
| `(0..1)` | Optional single slot |
| `(2)` | Fixed two-slot inline array |
| `(1..N)` where N ≤ 8 | Small inline array, stack-allocated |
| `(N..M)` | Pre-allocate N slots, enforce max M |
| `(*)` / `(1..*)` | Start with small capacity (e.g. 4), grow dynamically |
| `(0..*)` | Start empty, grow dynamically |

Roles with small fixed cardinalities — `(1)`, `(2)`, `(0..1)`, `(1..3)` — may be
stored inline within the edge record, avoiding heap allocation entirely.

### 0.5 Edge Storage Model

Edge storage uses a **dual-storage approach** separating connectivity data from edge
field data.

**Edge Partition:** Stores edge fields column-oriented, identical to node partitions. Each
edge type has its own partition. Edge fields (`date`, `salary`, `active`) are stored as
column arrays across all edges of that type.

**Role Index Tables:** For each role in each edge type, a sorted array of
`(node_id, edge_id)` pairs, sorted by `node_id`. One role index table exists per role
per edge type.

```
Role Index Tables for Marriage:

  Marriage.husband index:
    [ (doug_id, dne_id), (hans_id, hnl_id), (jarom_id, jnj_id), ... ]
    -- sorted by node_id

  Marriage.wife index:
    [ (julianna_id, jnj_id), (mikayla_id, dnm_id), (nini_id, dne_id), ... ]
    -- sorted by node_id

Edge Partition for Marriage (column store):
  date:  [ Date, Date, Date, ... ]    -- one entry per edge instance
```

**Traversal operations:**
- "Find all Marriage edges where node X fills husband" → binary search in
  `Marriage.husband` index for `(X, *)` → O(log n)
- "Get the wife for edge E" → lookup `Marriage.wife` index for `(*, E)` → O(log n)
- "Get the date for edge E" → direct column lookup in Marriage edge partition → O(1)

**Properties:**
- Type-partitioned scans: scanning all Marriages never touches Person data
- O(log n) traversal without pointer chasing
- `@unique(role1, role2)` constraints are implemented as composite indexes on role
  index tables
- Edge field data is physically separated from connectivity data

**Bidirectional roles** (`<->`) maintain a single role index table but support traversal
in both directions — the index is scanned for either node ID in the pair.

### 0.6 Vector\<N\> SIMD Alignment

`Vector<N>` fields have specific storage requirements to enable SIMD-accelerated
similarity operations.

**Alignment:** `Vector<N>` fields must be stored at addresses aligned to at least 16 bytes
(SSE minimum) or 32 bytes (AVX2 preferred). Implementations must pad preceding fields as
necessary to satisfy this alignment.

**Layout within partition:** `Vector<N>` fields are stored in **Struct-of-Arrays layout**
— all embedding vectors for all rows in a partition are stored contiguously, separate from
other column arrays:

```
Person Partition — Vector<384> field layout:

  Primary column store:
    [ id_0, id_1, ... ]
    [ age_0, age_1, ... ]
    [ name_ptr_0, name_ptr_1, ... ]

  Embedding column (contiguous, 32-byte aligned):
    [ vec_0[0..383], vec_1[0..383], vec_2[0..383], ... ]
    ↑ 32-byte aligned start
```

This layout enables vectorized dot-product and cosine distance computations to iterate
over the embedding column as a single contiguous memory region, maximizing cache
efficiency and SIMD utilization.

**Consequence:** `@index(vector)` operations on a field stored with this layout can
evaluate similarity against all vectors in a partition using SIMD instructions without
scattering across interleaved column data.

### 0.7 `@cold` Decorator

The `@cold` decorator declares that a field is expected to be accessed infrequently
relative to the primary query patterns for its type. The engine stores `@cold` fields in
a **secondary partition** separate from the primary column store.

```hql
DEFINE NODE Article {
    id:           UUID    @required,
    title:        String,
    status:       Enum<ArticleStatus>,
    published:    Bool    DEFAULT false,
    created_at:   Date    @readonly DEFAULT NOW(),

    body:         String? @cold,
    raw_html:     String? @cold,
    edit_history: String? @cold
};
```

**Behavior:**
- Queries referencing only non-`@cold` fields never open the secondary partition
- When any `@cold` field appears in a query's projection or filter, the engine performs a
  keyed lookup into the secondary partition using `id`
- `@cold` fields support the same types, constraints, and decorators as primary fields
- `@cold` applies to fields on both nodes and edges

**Warning `[WARN-PERF-003]`:** Using a `@cold` field in a `WHERE` clause emits:
*cold field used in filter predicate*. This indicates either the field is misclassified
or the query should be restructured. A `@cold` field in a filter predicate requires a
secondary partition lookup for every candidate row before filtering can proceed.

```hql
-- Emits [WARN-PERF-003]: restructure or reclassify
MATCH (a:Article) WHERE a.body LIKE "%keyword%" RETURN a.title;

-- Preferred: index a summary field in the primary partition
MATCH (a:Article) WHERE a.summary MATCHES "keyword" RETURN a.title;
```

**Interaction with `@index`:** A `@cold` field may carry `@index`. The index is stored
in the primary partition for fast lookup; index entries store only `id` and the indexed
value. Secondary partition access is still required to read the full field value.

**Note:** Engine-driven automatic partition splitting based on query execution statistics
is a valid future optimization that may reduce the need for explicit `@cold` declarations
in mature deployments. Explicit `@cold` provides a reliable signal at schema definition
time before query statistics are available.

### 0.8 `@materialized` as Strongly Preferred

`@computed(TRAVERSE)` without `@materialized` and `@computed(TRAVERSE) @materialized` are
not equivalent options with a performance tradeoff — they represent fundamentally different
access patterns with different storage models:

| Form | Read Cost | Write Cost | Storage |
|---|---|---|---|
| `@computed(TRAVERSE)` | Subquery per row (memoized per query) | None | Not stored |
| `@computed(TRAVERSE) @materialized` | O(1) column lookup | Recomputed on relevant writes | Stored column in primary partition |

The unmaterialized form scatters read access across the graph on every query execution,
defeating column-store caching and making query performance unpredictable under load.

**Normative guidance:** `@computed(TRAVERSE)` without `@materialized` is appropriate for
prototyping and genuinely low-frequency access. Production schemas must use `@materialized`
for any traversal-derived property accessed in queries.

`[WARN-PERF-001]` on traversal-computed properties in `WHERE` clauses is a **schema
design signal**, not a query tuning hint. The correct response is to add `@materialized`
to the property definition, not to restructure the query around the traversal.

### 0.9 DEFINE MATERIALIZED VIEW

`CROSS_TYPE` queries without a materialized view require scanning all partitions containing
the referenced field — O(partitions × rows). For production schemas, this defeats
type-partitioned storage. `DEFINE MATERIALIZED VIEW` creates a dedicated cross-type
partition indexed by specified fields.

**Syntax:**
```hql
DEFINE MATERIALIZED VIEW ViewName
    FOR [Type1, Type2, ...]
    ON [Field1, Field2, ...]
    INDEX [Field1, Field2, ...];
```

**Example:**
```hql
DEFINE MATERIALIZED VIEW PersonSearch
    FOR [Person, Employee, Admin]
    ON [LastName, FirstName, email]
    INDEX [LastName, FirstName];

-- This query now uses PersonSearch instead of a cross-partition scan:
MATCH (n) CROSS_TYPE WHERE n.LastName = 'Smith' RETURN n, TYPE(n);
```

**Properties:**
- The view maintains a sorted index over the specified fields across all listed types
- Each entry stores `(type_id, node_id)` alongside the indexed field values
- Updates to any indexed field in any listed type trigger incremental view maintenance
- `CROSS_TYPE` queries whose predicates match a view's index fields use the view
  automatically (query planner decision)

**Storage cost:** The view is a separate partition with storage proportional to
`(rows across all types) × (indexed field sizes)`. This is the correct tradeoff:
write-time storage cost for O(log n) cross-type query performance.

**Management:**
```hql
SHOW MATERIALIZED VIEWS;
VALIDATE MATERIALIZED VIEW ViewName;
REBUILD MATERIALIZED VIEW ViewName;
DROP MATERIALIZED VIEW ViewName;
```

**Error codes:**
| Code | Name | Description |
|---|---|---|
| `[6020]` | Materialized View Maintenance Failed | Incremental update could not be applied |
| `[6021]` | Materialized View Stale | View marked stale; cross-type queries fall back to partition scan with `[WARN-PERF-004]` |

---

## 1. Typed Enums

### 1.1 Motivation

v0.17 enums are unordered, unvalued constant sets. This works for closed vocabularies but
falls short in four scenarios:

- **Ordered categories** where range queries are meaningful (`Priority >= HIGH`)
- **Exact fractional values** where decimal precision is required (`TaxRate == TaxRate.STANDARD`)
- **External interop** where the serialized form must match a contract (`"GET"`, `"POST"`)
- **Capability/permission sets** where a field must hold *multiple* values simultaneously

### 1.2 Syntax

```hql
DEFINE ENUM EnumName            { ... };   -- plain (v0.17, unchanged)
DEFINE ENUM EnumName<INT>       { ... };   -- integer-backed
DEFINE ENUM EnumName<DECIMAL>   { ... };   -- decimal-backed
DEFINE ENUM EnumName<STRING>    { ... };   -- string-backed
DEFINE ENUM EnumName<FLAGS>     { ... };   -- bitfield
```

### 1.3 Plain Enum (Unchanged)

No type parameter. Unordered, string-keyed constants. No backing value. Cannot be used in
range comparisons.

```hql
DEFINE ENUM SpellSchool {
    ABJURATION, CONJURATION, DIVINATION, ENCHANTMENT,
    EVOCATION, ILLUSION, NECROMANCY, TRANSMUTATION
};
```

### 1.4 Integer-Backed Enum `<INT>`

Each constant is assigned an explicit integer value. Constants are mutually exclusive — a
field holds exactly one value. The integer enables ordering and range queries.

```hql
DEFINE ENUM Priority<INT> {
    LOW    = 1,
    MEDIUM = 2,
    HIGH   = 3,
    URGENT = 99
};
```

**Usage:**
```hql
MATCH (t:Task)
WHERE t.Priority >= Priority.HIGH
RETURN t.Title, t.Priority
ORDER BY t.Priority DESC;
```

**Rules:**
- All constants must have an explicit `= value` assignment. Partial assignment is `[2060]`.
- Values must be unique within the enum. Duplicate values are `[2061]`.
- Backing storage type is the smallest signed integer that fits the declared value range.
- Supports `==`, `!=`, `<`, `>`, `<=`, `>=` comparisons.

**Anti-pattern:** Do not use `<INT>` as a substitute for a numeric field. If the value
participates in arithmetic (`score * multiplier`), use a `Float` or `Int` field. `<INT>`
is for *ordered categories*, not numeric data. See §1.11 for the full rule on backing
value arithmetic.

### 1.5 String-Backed Enum `<STRING>`

Each constant is assigned an explicit string value that becomes the canonical serialized
form — used in storage, external API responses, and CSV/JSON interop.

```hql
DEFINE ENUM HttpMethod<STRING> {
    GET    = "GET",
    POST   = "POST",
    PUT    = "PUT",
    DELETE = "DELETE",
    PATCH  = "PATCH"
};
```

**Rules:**
- All constants must have an explicit `= "value"` assignment. Partial assignment is `[2060]`.
- String values must be unique within the enum. Duplicate values are `[2061]`.
- Supports `==` and `!=` only. Range operators are not valid.

### 1.6 Decimal-Backed Enum `<DECIMAL>`

Each constant is assigned an explicit `Decimal` value using the `d` literal suffix.
Constants are mutually exclusive. Decimal arithmetic is exact, making equality comparisons
safe and reliable.

```hql
DEFINE ENUM TaxRate<DECIMAL> {
    ZERO      = 0.00d,
    REDUCED   = 0.05d,
    STANDARD  = 0.20d,
    LUXURY    = 0.28d
};

DEFINE ENUM GPA<DECIMAL> {
    A_PLUS  = 4.30d,
    A       = 4.00d,
    A_MINUS = 3.70d,
    B_PLUS  = 3.30d,
    B       = 3.00d,
    B_MINUS = 2.70d,
    F       = 0.00d
};
```

**Rules:**
- All constants must have an explicit `= N.NNd` assignment. Partial assignment is `[2060]`.
- Values must be unique. Duplicate values are `[2061]`.
- Supports `==`, `!=`, `<`, `>`, `<=`, `>=`. Equality is exact.
- The `d` suffix is required. Assigning a plain float literal is `[2064]`.

**Why not `<FLOAT>`:** IEEE 754 floating-point does not guarantee exact equality.
`<DECIMAL>` uses fixed-point arithmetic throughout. `<FLOAT>` is excluded from v0.18.

**Note on arithmetic:** See §1.11. `<DECIMAL>` enum backing values are not arithmetic
operands. For computation involving the rate value, see the extraction pattern in §1.11.

### 1.7 FLAGS Enum `<FLAGS>`

Constants represent **combinable, non-exclusive** bit flags. A field of type
`Flags<EnumName>` holds a set of zero or more active flags simultaneously.

```hql
DEFINE ENUM Permission<FLAGS> { READ, WRITE, EXECUTE, ADMIN };

DEFINE ENUM DamageType<FLAGS> {
    ACID, BLUDGEONING, COLD, FIRE, FORCE,
    LIGHTNING, NECROTIC, PIERCING, POISON,
    PSYCHIC, RADIANT, SLASHING, THUNDER
};
```

**Field declaration:**
```hql
DEFINE FIELD Perms:       Flags<Permission>;
DEFINE FIELD DamageTypes: Flags<DamageType>;
```

**Usage:**
```hql
CREATE NODE u:User { Perms = Permission.READ | Permission.WRITE };

WHERE Permission.WRITE IN u.Perms
WHERE [Permission.READ, Permission.WRITE] ALL IN u.Perms
WHERE [Permission.ADMIN, Permission.EXECUTE] ANY IN u.Perms
WHERE [Permission.ADMIN] NONE IN u.Perms

SET u.Perms |= Permission.EXECUTE;
SET u.Perms &= ~Permission.READ;
SET u.Perms  = Permission.READ | Permission.WRITE;
```

**Rules:**
- Constants must NOT have explicit `= value` assignments. Manual assignment is `[2062]`.
- Engine assigns powers of two automatically (1, 2, 4, 8, ...).
- Maximum 64 constants per FLAGS enum. Exceeding this is `[2063]`.

#### 1.7.1 Engine Backing Type

The engine uses arbitrary-width integers to minimize memory usage. The backing type is
derived at schema definition time by counting constants:

| Flag Count | In-Memory Type | Storage Type | Remaining Before Migration |
|---|---|---|---|
| 1–8 | `u1`–`u8` | `u8` | 8 − N |
| 9–16 | `u9`–`u16` | `u16` | 16 − N |
| 17–32 | `u17`–`u32` | `u32` | 32 − N |
| 33–64 | `u33`–`u64` | `u64` | 64 − N |

Adding a flag within a byte boundary is a zero-cost migration. Crossing a boundary
(e.g. 8 → 9 flags) requires a storage migration and index rebuild.

```hql
SHOW ENUM DamageType;
-- DEFINE ENUM DamageType<FLAGS> { ACID, BLUDGEONING, COLD, ... }
-- Flags: 13 | In-memory: u13 | Storage: u16 | Remaining before migration: 3
```

#### 1.7.2 Migration

```hql
-- Adding a flag (zero-cost if within byte boundary)
ALTER ENUM DamageType<FLAGS> { ADD NECROTIC_FIRE };

-- Removing a flag (always requires migration)
MATCH (a:Attack) SET a.DamageTypes &= ~DamageType.BLUDGEONING;
ALTER ENUM DamageType<FLAGS> { DROP BLUDGEONING };
```

### 1.8 Enum Comparison: Plain vs Typed

| Feature | Plain | `<INT>` | `<DECIMAL>` | `<STRING>` | `<FLAGS>` |
|---|---|---|---|---|---|
| Mutually exclusive | ✅ | ✅ | ✅ | ✅ | ❌ (set) |
| Range queries (`>=`) | ❌ | ✅ | ✅ | ❌ | ❌ |
| Equality safe | ✅ | ✅ | ✅ | ✅ | N/A |
| Explicit values required | ❌ | ✅ | ✅ | ✅ | ❌ (forbidden) |
| Multi-value field | ❌ | ❌ | ❌ | ❌ | ✅ |
| `IN` membership test | ❌ | ❌ | ❌ | ❌ | ✅ |
| Serialized as | Constant name | Integer | Decimal string | String value | Integer (bitmask) |

### 1.9 Error Codes (New)

| Code | Name | Description |
|---|---|---|
| `[2060]` | Partial Enum Values | Valued enum has mix of assigned and unassigned constants |
| `[2061]` | Duplicate Enum Value | Two constants share the same backing value |
| `[2062]` | Illegal Flags Value | `<FLAGS>` constant has explicit `= value` assignment |
| `[2063]` | Flags Ceiling Exceeded | `<FLAGS>` enum exceeds 64 constants |
| `[2064]` | Decimal Literal Required | `<DECIMAL>` constant assigned without `d` suffix |
| `[2065]` | Unknown Enum Backing Type | `<TYPE>` parameter is not a permitted backing type |

### 1.10 Implementation Note — Permitted Backing Types

**Permitted:**

| Type | Backing Primitive | Equality Safe | Range Queries |
|---|---|---|---|
| *(none)* | String key (intern table) | ✅ | ❌ |
| `<INT>` | Signed integer (smallest fit) | ✅ | ✅ |
| `<DECIMAL>` | Fixed-point decimal | ✅ | ✅ |
| `<STRING>` | UTF-8 string | ✅ | ❌ |
| `<FLAGS>` | Unsigned integer (`uN`, byte-aligned storage) | N/A | ❌ |

**Excluded:**

| Type | Reason |
|---|---|
| `<FLOAT>` | IEEE 754 does not guarantee exact equality. `<DECIMAL>` covers all legitimate fractional use cases. |
| `<BOOL>` | A boolean enum has at most two constants — use a `Bool` field. |
| `<DATE>` | Date constants are inherently stale. Use `DEFINE NODE` with `Month` and `Day` fields. |
| Complex types | Enum constants must be scalar, comparable, and serializable to a single primitive. |

The parser must reject any `<TYPE>` not in the permitted set with `[2065]`.

### 1.11 Enum Backing Values Are Not Arithmetic Operands

Enum backing values — regardless of type — are **identity markers**, not numeric operands.
A backing value is the canonical serialized form and the basis for comparison. It is not
a participant in arithmetic. This applies to all typed enum variants.

```hql
-- VALID: comparison using backing value ordering
WHERE t.Priority >= Priority.HIGH
WHERE s.GPA >= GPA.B_PLUS
WHERE invoice.Rate == TaxRate.STANDARD

-- INVALID: arithmetic on enum backing values
WHERE price * invoice.Rate > 100           -- [2001] Type mismatch
WHERE t.Priority + 1 == Priority.URGENT   -- [2001] Type mismatch
```

If a backing value needs to participate in arithmetic, the field should be typed as the
corresponding primitive (`Int`, `Float`, `Decimal(P,S)`).

**`<DECIMAL>` specifically:** The exact decimal arithmetic of `<DECIMAL>` is available
for comparison, not for computation. `TaxRate.STANDARD` can be compared to other
`TaxRate` values; it cannot be multiplied against a price. To compute with the rate,
extract it via CASE:

```hql
MATCH (i:Invoice)
WITH i, CASE i.Rate
    WHEN TaxRate.ZERO     THEN 0.00d
    WHEN TaxRate.REDUCED  THEN 0.05d
    WHEN TaxRate.STANDARD THEN 0.20d
    WHEN TaxRate.LUXURY   THEN 0.28d
END AS rate_decimal
RETURN i.Amount * rate_decimal AS tax_amount;
```

#### 1.11.1 Unit Conversion Systems — Recommended Pattern

A common scenario that appears to call for enum arithmetic is unit conversion: grams,
milligrams, kilograms, ounces, pounds, cups, gallons, and so on. It may be tempting to
model these as a `<DECIMAL>` enum where the backing value is a conversion factor:

```hql
-- TEMPTING BUT WRONG for unit conversion systems
DEFINE ENUM MassUnit<DECIMAL> {
    MILLIGRAM = 0.001d,
    GRAM      = 1.000d,
    KILOGRAM  = 1000.0d,
    OUNCE     = 28.3495d,
    POUND     = 453.592d
};
```

The problem is not that the backing values are wrong — they are numerically correct. The
problem is that this model:

- Requires a **schema migration to add any new unit** (FLUID_OUNCE, TABLESPOON, etc.)
- Buries the semantic meaning of the conversion factor (to-base, to-display) in the enum
  declaration with no self-documenting name
- Cannot represent units with additional properties (display symbol, plural name, system)
- Produces no queryable unit entities — you cannot ask "give me all supported mass units"

The graph-native model is a **unit node type** with `@readonly` conversion fields and
**`@pure` UDFs** for conversion logic:

```hql
-- Schema
DEFINE FIELD [
    unit_name:      String          @unique @display,
    unit_symbol:    String          @unique,
    to_base_factor: Decimal(15, 8)  @readonly
];

DEFINE NODE MassUnit {
    id,
    unit_name,
    unit_symbol,
    to_base_factor
};

DEFINE ROLE [
    measured_ingredient ALLOWS Ingredient,
    mass_unit           ALLOWS MassUnit,
] ALLOWS MassUnit;

DEFINE EDGE IngredientUnit {
    measured_ingredient <- (1),
    mass_unit           -> (1),
    amount: Decimal(15, 6)
};

-- Conversion UDF
DEFINE FUNCTION @pure ConvertMass(
    amount:      Decimal(15, 6),
    from_factor: Decimal(15, 8),
    to_factor:   Decimal(15, 8)
): Decimal(15, 6) {
    RETURN TO_DECIMAL(amount * from_factor / to_factor, 15, 6);
};

-- Seed data (CREATE once, query forever)
CREATE NODE [
    gram:MassUnit      { id = UUID(), unit_name = "gram",      unit_symbol = "g",  to_base_factor = 1.00000000d },
    kilogram:MassUnit  { id = UUID(), unit_name = "kilogram",  unit_symbol = "kg", to_base_factor = 1000.00000000d },
    milligram:MassUnit { id = UUID(), unit_name = "milligram", unit_symbol = "mg", to_base_factor = 0.00100000d },
    ounce:MassUnit     { id = UUID(), unit_name = "ounce",     unit_symbol = "oz", to_base_factor = 28.34952000d },
    pound:MassUnit     { id = UUID(), unit_name = "pound",     unit_symbol = "lb", to_base_factor = 453.59237000d },
    cup:MassUnit       { id = UUID(), unit_name = "cup",       unit_symbol = "c",  to_base_factor = 236.58824000d },
];

-- Usage: convert all ingredients to kilograms
MATCH (e:IngredientUnit)-[:mass_unit]->(u:MassUnit)
MATCH (target:MassUnit { unit_symbol = "kg" })
RETURN
    e.amount AS original_amount,
    u.unit_symbol AS original_unit,
    ConvertMass(e.amount, u.to_base_factor, target.to_base_factor) AS kg;
```

**Advantages over enum-based units:**
- Add `TABLESPOON` with a `CREATE NODE` — no schema migration required
- `to_base_factor` is explicitly named and typed
- Units are queryable: `MATCH (u:MassUnit) RETURN u.unit_name, u.unit_symbol ORDER BY u.to_base_factor`
- `ConvertMass` is a pure function that can be unit-tested independently
- Units can carry additional properties without schema changes to every consumer
- The same pattern extends to any unit domain (volume, temperature, currency) with identical structure

This pattern applies equally to any domain where a lookup table of factors drives
computation: currency exchange rates, ingredient densities, material costs per unit,
tax rates by jurisdiction.

---

## 2. Field, Edge, and Node Defaults

### 2.1 Motivation

v0.17 has no mechanism to declare a default value for a field. Every `CREATE NODE` or
`CREATE EDGE` must supply all non-nullable fields explicitly. `DEFAULT` moves obvious
schema-level defaults out of application code and into the schema where they belong.

`DEFAULT` applies at three levels, evaluated in a defined resolution order:
1. **Global field default** — declared on `DEFINE FIELD`, applies to all nodes and edges
   that include the field unless overridden
2. **Node-level default** — declared inline in `DEFINE NODE`, overrides the global default
   for that specific node type
3. **Edge-level default** — declared inline in `DEFINE EDGE`, overrides the global default
   for that specific edge type

### 2.2 Default Resolution Order

When a field is omitted from a `CREATE` statement, the engine resolves the default using
this priority chain:

```
1. Explicit value in CREATE statement           (highest — always wins)
2. Node-level or edge-level default override    (type-specific)
3. Global field default                         (DEFINE FIELD DEFAULT)
4. null                                         (if field is nullable: String?, Int?, etc.)
5. Error [3015] Missing Required Field          (if field is non-nullable and no default exists)
```

This means a node type can deliberately use a different default than the global field
definition specifies, which is the primary use case for node-level defaults.

### 2.3 Syntax

```hql
-- Global field default
DEFINE FIELD FieldName: DataType DEFAULT expression;
DEFINE FIELD FieldName: DataType @decorator DEFAULT expression;

-- Node-level default override (inline in DEFINE NODE)
DEFINE NODE NodeTypeName {
    existing_global_field DEFAULT override_expression,
    inline_field: DataType DEFAULT expression,   -- STRICT_MODE = false only
    ...
} [{ constraints: [...] }];

-- Edge field default (inline in DEFINE EDGE)
DEFINE EDGE EdgeTypeName {
    role <- (Cardinality),
    FieldName: DataType DEFAULT expression,
    ...
};
```

`DEFAULT` is chosen over `=` because `=` is the instance-level value assignment operator
in `CREATE`/`SET`/`MERGE`. Using `=` in `DEFINE FIELD`, `DEFINE NODE`, or `DEFINE EDGE`
would create a syntactic ambiguity. `DEFAULT` is unambiguous at a glance.

### 2.4 Examples

**Global field defaults:**
```hql
DEFINE FIELD [
    created_at: Date                  @readonly DEFAULT NOW(),
    updated_at: Date                            DEFAULT NOW(),
    score:      Int                             DEFAULT 0,
    is_active:  Bool                            DEFAULT true,
    tags:       List<String>                    DEFAULT [],
    status:     Enum<AccountStatus>             DEFAULT AccountStatus.ACTIVE,
    perms:      Flags<Permission>               DEFAULT Permission.READ,
];
```

**Node-level default overrides:**
```hql
-- Global field: status defaults to ACTIVE
-- TemporaryUser overrides to PENDING for this type only
DEFINE NODE TemporaryUser {
    id,
    name,
    email,
    status DEFAULT AccountStatus.PENDING,   -- overrides global AccountStatus.ACTIVE
    created_at                              -- uses global @readonly DEFAULT NOW()
} {
    constraints: { has_email: .email != "" }
};

-- RegularUser uses the global default (AccountStatus.ACTIVE) — no override needed
DEFINE NODE RegularUser {
    id,
    name,
    email,
    status,      -- inherits global DEFAULT AccountStatus.ACTIVE
    created_at   -- inherits global DEFAULT NOW()
};

-- AdminUser overrides both status and permissions
DEFINE NODE AdminUser {
    id,
    name,
    email,
    status  DEFAULT AccountStatus.ACTIVE,
    perms   DEFAULT Permission.READ | Permission.WRITE | Permission.ADMIN,
    created_at
};
```

**Node-level inline field defaults (STRICT_MODE = false only):**
```hql
DEFINE NODE Player {
    id,
    name,
    score:  Int  DEFAULT 0,    -- inline field definition with default
    level:  Int  DEFAULT 1,    -- inline field definition with default
    active: Bool DEFAULT true
};
```

**Edge field defaults:**
```hql
DEFINE EDGE Employment {
    employee    <- (1),
    employer    <- (1),
    start_date: Date              DEFAULT NOW(),
    active:     Bool              DEFAULT true,
    salary:     Decimal(10, 2),
    end_date:   Date?
};

DEFINE EDGE Friendship {
    friend <-> (*),
    since:   Date DEFAULT NOW(),
    active:  Bool DEFAULT true
};

DEFINE EDGE Enrollment {
    student   <- (1),
    course    <- (1),
    enrolled: Date                   DEFAULT NOW(),
    status:   Enum<EnrollmentStatus> DEFAULT EnrollmentStatus.ACTIVE
} @unique(student, course);
```

### 2.5 Permitted Functions in DEFAULT Expressions

| Purity | Permitted | Notes |
|---|---|---|
| `@pure` | ✅ Yes | Logic and arithmetic. Most common for computed initial values. |
| `@nondeterministic` | ✅ Yes | `NOW()`, `UUID()`. Evaluated fresh at each write. |
| `@readonly` | ❌ No | Graph traversal is forbidden in defaults. Error `[2070]`. |

`@pure` UDFs are explicitly permitted in default expressions:

```hql
DEFINE FUNCTION @pure DefaultHandle(name: String): String {
    RETURN LOWER(TRIM(name));
};

DEFINE FIELD handle: String DEFAULT DefaultHandle("unnamed");
```

### 2.6 Behavior

**At CREATE time:** Omitted fields with `DEFAULT` have their default expression evaluated
and written as the initial value, following the resolution order in §2.2.

```hql
CREATE NODE p:RegularUser { name = "Alice", email = "alice@example.com" };
-- id, status, created_at receive defaults per global field definitions

CREATE NODE p:TemporaryUser { name = "Bob", email = "bob@example.com" };
-- status = AccountStatus.PENDING (node-level override)
-- created_at = NOW() (from global field default)

CREATE NODE p:AdminUser { name = "Carol", email = "carol@example.com" };
-- perms = READ | WRITE | ADMIN (node-level override)
-- status = AccountStatus.ACTIVE (node-level, same as global here)

CREATE EDGE e:Employment { employee => alice, employer => corp, salary = 75000.00d };
-- start_date and active receive edge-level defaults: NOW() and true
```

**At MERGE time:** `DEFAULT` applies only on the `ON CREATE` path. Defaults are not
re-applied to existing records on `ON MATCH`.

**Expression evaluation:** Evaluated at write time, not at schema definition time.
`NOW()` produces the timestamp of the `CREATE` call.

### 2.7 Interaction with `@readonly`

```hql
DEFINE FIELD created_at: Date @readonly DEFAULT NOW();
```

`@readonly` prevents modification after creation. `DEFAULT NOW()` ensures the field is
always populated. Together they enforce an auditable, tamper-resistant creation timestamp
at the schema level with no application code required. This pattern applies equally to
global field definitions, node-level overrides, and edge field definitions.

### 2.8 Constraint Interaction

A `DEFAULT` value is written before node-level or edge-level constraints are evaluated.
A default that violates a constraint fails with `[3011]` (node) or `[3013]` (edge) — this
is a schema design error detectable at schema validation time.

```hql
DEFINE FIELD age: Int DEFAULT -1;
DEFINE NODE Person { age } { constraints: [.age >= 0] };

CREATE NODE p:Person {};  -- Fails [3011]: age default (-1) violates .age >= 0
```

**Node-level default override violating node constraint:**
```hql
DEFINE FIELD status: Enum<AccountStatus> DEFAULT AccountStatus.ACTIVE;

DEFINE NODE TemporaryUser {
    status DEFAULT AccountStatus.DELETED   -- bad override
} {
    constraints: { not_deleted: .status != AccountStatus.DELETED }
};

CREATE NODE t:TemporaryUser { name = "Bob" };
-- Fails [3011]: status default (DELETED) violates not_deleted constraint
-- Schema design error — detectable at VALIDATE SCHEMA time
```

### 2.9 Error Codes (New)

| Code | Name | Description |
|---|---|---|
| `[2070]` | Invalid Default Expression | Default uses a forbidden function (e.g. `@readonly` UDF) |
| `[2071]` | Default Type Mismatch | Default expression return type does not match field type |
| `[3015]` | Missing Required Field | Non-nullable field with no default omitted from CREATE |

---

## 3. Extended Cardinality

### 3.1 Motivation

v0.17 cardinality is binary: `(ONE)` or `(MANY)`. Rules that are naturally part of a
relationship's structure — "a marriage has exactly 2 spouses", "an event has 10–500
attendees" — are forced into edge constraint blocks. Extended cardinality expresses these
rules in the role declaration where they belong, and enables the engine to enforce them
as structural properties rather than evaluated expressions.

### 3.2 Syntax

```
(N)      Exact count. N is a positive integer ≥ 1.
(*)      Unbounded. Canonical form of legacy MANY. Equivalent to (1..*).
(N..M)   Range. Both bounds explicit.
           N: non-negative integer (0 permitted as lower bound only)
           M: positive integer strictly greater than N, or * for unbounded
```

**All valid forms:**
```hql
role <- (1)       -- exactly 1          (legacy ONE)
role <- (*)       -- 1 or more          (legacy MANY)
role <- (2)       -- exactly 2
role <- (1..50)   -- between 1 and 50
role <- (0..1)    -- 0 or 1             (replaces role?)
role <- (0..*)    -- 0 or more          (optional unbounded)
role <- (1..*)    -- 1 or more          (explicit form of *)
role <- (5..100)  -- between 5 and 100
```

### 3.3 Validity Rules

```
(N)      VALID   if N ≥ 1
(N..M)   VALID   if N ≥ 0 AND M > N AND (M is positive integer OR M == *)
(0)      INVALID — use (0..1) or (0..*) for zero-minimum
(1..1)   INVALID — upper must be strictly > lower; use (1) instead
(N..N)   INVALID for any N — use exact form (N) instead
(5..3)   INVALID — upper < lower
```

### 3.4 Named Aliases

`ONE` and `MANY` remain valid as aliases for full backward compatibility:

```
ONE   ≡ (1)
MANY  ≡ (*)  ≡ (1..*)
```

### 3.5 Examples

**Marriage — exact count replaces edge constraint:**
```hql
-- v0.17
DEFINE EDGE Marriage {
    spouse <-> (MANY)
} {
    constraints: [COUNT(DISTINCT spouse) == 2, spouse[0] != spouse[1]]
};

-- v0.18
DEFINE EDGE Marriage { spouse <-> (2) };
```

**Event — range cardinality:**
```hql
DEFINE EDGE Conference {
    host      <- (1..3),
    keynote   <- (1..5),
    attendee  <- (10..500),
    sponsor   <- (0..20),
    Date, Venue
};
```

**Optional role — replaces `?`:**
```hql
-- v0.17
DEFINE EDGE Adoption { parent <- (1..2), child <- (ONE), witness? <- (ONE) };

-- v0.18
DEFINE EDGE Adoption { parent <- (1..2), child <- (1), witness <- (0..1) };
```

### 3.6 Deprecation of `?` Role Suffix

`?` on roles (e.g. `mother? <- (ONE)`) is formally deprecated in v0.18, superseded by
`(0..1)`. Parser emits `[WARN-SCHEMA-002]`. Removed in v0.19.

`@optional` was deprecated in v0.16. `?` was its replacement. `(0..N)` is now the single
canonical mechanism for optional roles — the deprecation chain is complete.

### 3.7 Cardinality Enforcement Model

Cardinality is validated as a discrete step in the write pipeline for all write operations:

```
1. Node constraints    (each node being bound)
2. Cardinality bounds  (count of nodes per role)
3. Role constraints    (each node's eligibility)
4. Edge constraints    (cross-role relational rules)
```

**Full mutation enforcement:** Cardinality bounds are enforced on **all write operations**
that modify role membership — not only on initial edge creation. `SET +=` and `SET -=`
operations on bounded roles trigger `[3014] Role Cardinality Violated` if the operation
would push the role count outside its declared bounds.

```hql
DEFINE EDGE Conference {
    attendee <- (10..500),
    sponsor  <- (0..20)
};

MATCH (c:Conference { id = $id })

SET c.attendee -= departing_attendee;
-- Fails [3014] if this would drop attendee count below 10

SET c.attendee += new_attendee;
-- Fails [3014] if this would push attendee count above 500

SET c.sponsor += new_sponsor;
-- Fails [3014] if this would push sponsor count above 20
```

**Interaction with `(0..1)` roles:** Setting a `(0..1)` role to null via
`SET e.role = null` is valid and equivalent to removing the binding. Setting it to a
node when already bound is a replacement — cardinality remains 1, no violation.

### 3.8 Error Codes (New)

| Code | Name | Description |
|---|---|---|
| `[2080]` | Invalid Cardinality Expression | Malformed cardinality (e.g. `(0)`, `(3..3)`, `(5..3)`) |
| `[3014]` | Role Cardinality Violated | Node count for role is outside declared bounds — on CREATE or on SET +=/-= |

---

## 4. Batch / Multi-Syntax

### 4.1 Motivation

Repeated keywords create visual noise that obscures the structure of a schema or data
file. The batch form factors out the keyword and groups related declarations into a single
statement. It is purely syntactic sugar — every batch form compiles to the same AST as
the equivalent sequence of single statements.

### 4.2 DEFINE Batch Forms

**DEFINE FIELD:**
```hql
DEFINE FIELD [
    id:         UUID                   @required,
    name:       String                 @required,
    gender:     Enum<Gender>           @required,
    age:        Int,
    created_at: Date @readonly         DEFAULT NOW(),
    status:     Enum<AccountStatus>    DEFAULT AccountStatus.ACTIVE,
];
```

**DEFINE ROLE — uniform ALLOWS:**
```hql
DEFINE ROLE [
    father   { .gender == Gender.MALE,   .age >= 18 },
    mother   { .gender == Gender.FEMALE, .age >= 18 },
    husband  { .gender == Gender.MALE,   .age >= 18 },
    wife     { .gender == Gender.FEMALE, .age >= 18 },
    friend,
    owner,
] ALLOWS Person;
```

**DEFINE ROLE — heterogeneous ALLOWS:**
```hql
DEFINE ROLE [
    character    ALLOWS [PlayerCharacter, NonPlayerCharacter, Creature],
    quest_giver  ALLOWS [NonPlayerCharacter, Faction, Deity],
    quest_target ALLOWS [NonPlayerCharacter, Creature, Location, Item],
    merchant     ALLOWS [NonPlayerCharacter],
    customer     ALLOWS [PlayerCharacter, NonPlayerCharacter],
    owner        ALLOWS [PlayerCharacter, NonPlayerCharacter, Faction],
];
```

The two forms cannot be mixed within one block.

**DEFINE NODE:**
```hql
DEFINE NODE [
    RegularUser {
        id, name, email, status, created_at
    } {
        constraints: { has_email: .email != "" }
    },
    TemporaryUser {
        id, name, email,
        status DEFAULT AccountStatus.PENDING
    } {
        constraints: { has_email: .email != "" }
    },
    AdminUser {
        id, name, email,
        status DEFAULT AccountStatus.ACTIVE,
        perms  DEFAULT Permission.READ | Permission.WRITE | Permission.ADMIN,
        created_at
    },
];
```

**DEFINE EDGE:**
```hql
DEFINE EDGE [
    Marriage {
        husband <- (1),
        wife    <- (1),
        date:   Date DEFAULT NOW()
    } {
        constraints: {
            different_people: .husband != .wife,
            valid_date:       .date <= NOW()
        }
    },
    Family {
        father   -> (1),
        mother   -> (1),
        son      <- (*),
        daughter <- (*)
    } {
        constraints: [.father != .mother]
    },
    Friendship { friend <-> (*), since: Date DEFAULT NOW() },
    Owns       { owner -> (1), pet <- (1) },
];
```

**DEFINE [mixed]:**
```hql
DEFINE [
    ENUM  [ Gender { MALE, FEMALE } ],
    FIELD [
        id:   UUID   @required,
        name: String @required,
        age:  Int
    ],
    ROLE  [
        friend ALLOWS Person,
        pet    ALLOWS Dog
    ],
    NODE  [
        Person { id, name, age },
        Dog    { id, name }
    ],
    EDGE  [
        Friendship { friend <-> (*) },
        Owns       { owner -> (1), pet <- (1) }
    ],
];
```

Within a `DEFINE [...]` block, all names across all sub-blocks are collected in Pass 1
before any references are resolved. A `NODE` entry may reference a `FIELD` declared
later in the same block — hoisting applies across the entire block.

**DEFINE SCHEMA:**
```hql
DEFINE SCHEMA Family [
    ENUM  [ Gender { MALE, FEMALE } ],
    FIELD [
        id:     UUID         @required,
        name:   String       @required,
        gender: Enum<Gender> @required,
        age:    Int
    ],
    ROLE [
        father  { .gender == Gender.MALE,   .age >= 18 },
        mother  { .gender == Gender.FEMALE, .age >= 18 },
        husband { .gender == Gender.MALE,   .age >= 18 },
        wife    { .gender == Gender.FEMALE, .age >= 18 },
        friend,
    ] ALLOWS Person,
    NODE  [ Person { id, name, gender, age } ],
    EDGE  [
        Marriage {
            husband <- (1),
            wife    <- (1),
            date:   Date DEFAULT NOW()
        } {
            constraints: { different_people: .husband != .wife }
        },
        Friendship { friend <-> (*), since: Date DEFAULT NOW() }
    ],
];
```

Named schemas are importable, validatable, and migratable as a unit:

```hql
IMPORT SCHEMA Family FROM Core.People;
VALIDATE SCHEMA Family;
ALTER SCHEMA Family { ADD FIELD [ nickname: String? ] };
```

`DEFINE SCHEMA` is documented in the Reference Appendices as a named, importable schema
unit and is the preferred form for schemas intended to be versioned and migrated as a unit.

### 4.3 CREATE Batch Forms

**CREATE NODE:**
```hql
CREATE NODE [
    doug:Person  { id = UUID(), name = "Doug",  gender = Gender.MALE,   age = 50 },
    nini:Person  { id = UUID(), name = "Nini",  gender = Gender.FEMALE, age = 48 },
    hans:Person  { id = UUID(), name = "Hans",  gender = Gender.MALE,   age = 20 },
    tili:Person  { id = UUID(), name = "Tili",  gender = Gender.FEMALE, age = 12 },
];
```

**CREATE EDGE:**
```hql
CREATE EDGE [
    dne:Marriage {
        husband => doug,
        wife    => nini
    },
    andersonFam:Family {
        father   => doug,
        mother   => nini,
        son      => [hans],
        daughter => [tili]
    },
];
```

**CREATE [NODE, EDGE] — cross-type atomic creation with shared variable scope:**
```hql
CREATE [
    NODE [
        lucy:Person     { id = UUID(), name = "Lucy",     gender = Gender.FEMALE, age = 24 },
        willard:Person  { id = UUID(), name = "Willard",  gender = Gender.MALE,   age = 25 },
        nova:Dog        { id = UUID(), name = "Nova" }
    ],
    EDGE [
        hnl:Marriage { husband => hans, wife => lucy },
        wnt:Marriage { husband => willard, wife => tili },
        dmn:Owns     { owner => [willard, tili], pet => nova }
    ]
];
```

**Variable scoping rule:** Variables bound in the `NODE [...]` sub-block are in scope for
the `EDGE [...]` sub-block within the same `CREATE [...]` statement. They are not in scope
outside the statement.

**Atomicity:** All batch `CREATE` forms are implicitly atomic. An error in any entry rolls
back the entire batch unless the surrounding transaction uses `BEGIN ON ERROR CONTINUE`.

### 4.4 Semantic Grouping Guideline

Batch forms are designed for **semantic grouping** — declarations that belong together
logically. They are not a compression mechanism for large schemas.

**Appropriate:** All fields for a logical domain grouped together; all edges for a schema
block that form a coherent subsystem.

**Inappropriate:** 40 unrelated node types in a single `DEFINE NODE [...]` block. When a
batch block becomes difficult to navigate vertically, the content likely belongs in
separate named blocks or separate files (see §5).

### 4.5 Excluded Batch Forms

**Rejected — Type-grouped DEFINE ROLE:** Rejected because it inverts HyperQL's role-
centric mental model and fragments role definitions across multiple entries, making it
impossible to see a role's full ALLOWS set from a single location.

**Rejected — Nested DEFINE ROLE:** Rejected for extreme cognitive complexity with no
practical benefit over the heterogeneous form.

---

## 5. Namespace Modularization

### 5.1 Dot-Hierarchy Naming

Namespaces use dot-separated segments to form a hierarchy:

```
Core                    -- root module
Core.Game               -- submodule of Core
Core.Game.Combat        -- submodule of Core.Game
Core.People             -- sibling of Core.Game under Core
```

### 5.2 Multi-File Rules

Multiple `.hql` files may share the same fully-qualified namespace. Their definitions are
merged additively at compile time. All files sharing a namespace participate in the same
hoisting scope.

No two files in the same namespace may define the same name.
Error `[1010] Namespace Collision`.

### 5.3 Access Rules

```
Same namespace       → implicit access, no import required
Child namespace      → implicit access
Parent namespace     → implicit access
Sibling / unrelated  → explicit IMPORT required
```

### 5.4 File-to-Module Convention

The recommended directory convention:

```
/schema
  /Core
    /Game
      combat.hql    → Core.Game.Combat
      magic.hql     → Core.Game.Magic
    game.hql        → Core.Game
  /People
    people.hql      → Core.People
```

Implementations must document their resolution strategy. The directory convention is
recommended but not required.

### 5.5 Namespace Block Form

```hql
DEFINE NAMESPACE Core.Game.Combat [
    ENUM  [ DamageType<FLAGS> { FIRE, COLD, LIGHTNING } ],
    FIELD [ initiative: Int, hit_points: Int ],
    NODE  [ CombatEncounter { initiative, hit_points } ],
];
```

The block form implies single-file containment. The preamble form (`DEFINE NAMESPACE X;`
at the top of a file) implies multi-file merging. Both are valid and cannot be combined
in the same file.

### 5.6 STRICT_MODE and Multi-File Namespaces

`STRICT_MODE` is a **per-file declaration**, not a per-namespace property.

```hql
-- combat.hql
DEFINE NAMESPACE Core.Game.Combat STRICT_MODE = false;
-- Inline property definitions permitted only within this file

-- items.hql
DEFINE NAMESPACE Core.Game.Combat;
-- STRICT_MODE = true (default) — inline definitions NOT permitted here
```

Two files sharing the same namespace may have different `STRICT_MODE` values. Definitions
from both files are merged into the same namespace scope, but the inline property
definition permission is scoped to the file that declared it. A strict file referencing
types defined in a non-strict file is valid; the strict file cannot use inline property
syntax regardless of the source file's mode.

### 5.7 Error Codes (New)

| Code | Name | Description |
|---|---|---|
| `[1010]` | Namespace Collision | Two files in the same namespace define the same name |
| `[1011]` | Unresolved Import | `IMPORT` references a namespace or name that does not exist |
| `[1012]` | Circular Import | Import chain creates a circular dependency |

---

## 6. Query Block Syntax

### 6.1 Motivation

The readability principle that motivated batch schema definitions applies to queries.
Complex WHERE clauses, multi-pattern MATCH statements, and large RETURN projections benefit
from the same `keyword [entries]` structure that makes schema files scannable. The balanced
delimiter property also applies here, enabling reliable query formatting and transformation
by tooling.

### 6.2 MATCH Block

All patterns in the block are resolved together as a join. `OPTIONAL` becomes a
per-pattern modifier inside the block, replacing the `OPTIONAL MATCH` clause form:

```hql
MATCH [
    (p:Person { name = "Alice" }),
    OPTIONAL (f:Person)-[:Friendship]-(p),
    (c:Commute { driver => p })
];
```

### 6.3 WHERE Block

Each entry is an expression. Entries are implicitly ANDed.

```hql
WHERE [
    p.age >= 18,
    p.status == AccountStatus.ACTIVE,
    p.email != ""
];
```

### 6.4 WITH Block

```hql
WITH [
    p,
    COLLECT(f.name) AS friends,
    COUNT(f)        AS friend_count,
    friend_count * 2 AS weighted_score
];
```

### 6.5 RETURN Block

```hql
RETURN [
    name:    p.name,
    age:     p.age,
    friends: COLLECT(f.name),
    rank:    RANK() OVER (ORDER BY p.age DESC)
];
```

### 6.6 Full Query Comparison

```hql
-- Current style
MATCH (p:Person)
OPTIONAL MATCH (f:Person)-[:Friendship]-(p)
WHERE p.age >= 18
  AND p.status == AccountStatus.ACTIVE
WITH p, COLLECT(f.name) AS friends, COUNT(f) AS friend_count
RETURN p.name, friend_count, friends
ORDER BY friend_count DESC
LIMIT 10;

-- Block style
MATCH [
    (p:Person),
    OPTIONAL (f:Person)-[:Friendship]-(p)
]
WHERE [
    p.age >= 18,
    p.status == AccountStatus.ACTIVE
]
WITH [
    p,
    COLLECT(f.name) AS friends,
    COUNT(f)        AS friend_count
]
RETURN [
    name:         p.name,
    friend_count: friend_count,
    friends:      friends
]
ORDER BY friend_count DESC
LIMIT 10;
```

Both forms are always valid. Block form is appropriate when a clause has three or more
entries and alignment improves readability. Single-condition clauses (`WHERE p.age > 18`)
have no reason to use block form.

`ORDER BY`, `LIMIT`, `SKIP`, `GROUP BY`, and `UNION` remain as trailing single-line
clauses and do not benefit from block form.

### 6.7 Whitespace-Free Readability Guarantee

```
MATCH[(p:Person),OPTIONAL(f:Person)-[:Friendship]-(p)]WHERE[p.age>=18,p.status==AccountStatus.ACTIVE]WITH[p,COLLECT(f.name)AS friends,COUNT(f)AS friend_count]RETURN[name:p.name,friend_count:friend_count,friends:friends]ORDER BY friend_count DESC LIMIT 10;
```

---

## 7. Backward Compatibility

All v0.17 schemas and queries are valid in v0.18 without modification.

- `ONE` and `MANY` remain as permanent aliases for `(1)` and `(*)`.
- Plain `DEFINE ENUM` without a type parameter is unchanged.
- `?` on roles emits `[WARN-SCHEMA-002]` but functions correctly until v0.19.
- All single-statement forms remain permanently valid alongside their batch equivalents.
- Preamble `DEFINE NAMESPACE` files are unchanged; block-form namespace is additive.
- `OPTIONAL MATCH` as a standalone clause remains valid; the `OPTIONAL` pattern modifier
  inside `MATCH [...]` is an additional form, not a replacement.
- `@computed(TRAVERSE)` without `@materialized` remains valid; `[WARN-PERF-001]` now
  carries stronger normative guidance that it is a schema design signal requiring
  `@materialized`, not a query tuning hint.

---

## 8. Deprecations

| Feature | Deprecated By | Removed In |
|---|---|---|
| `role? <- (ONE)` suffix | `role <- (0..1)` | v0.19 |
| `MANY` keyword | `(*)` or `(1..*)` | No current plan (alias retained) |
| `ONE` keyword | `(1)` | No current plan (alias retained) |

---

## 9. Summary of New Syntax

```hql
-- Typed enums
DEFINE ENUM Priority<INT>      { LOW = 1, MEDIUM = 2, HIGH = 3, URGENT = 99 };
DEFINE ENUM TaxRate<DECIMAL>   { ZERO = 0.00d, REDUCED = 0.05d, STANDARD = 0.20d };
DEFINE ENUM Direction<STRING>  { NORTH = "N", SOUTH = "S", EAST = "E", WEST = "W" };
DEFINE ENUM Permission<FLAGS>  { READ, WRITE, EXECUTE, ADMIN };

-- Global field defaults
DEFINE FIELD created_at: Date @readonly DEFAULT NOW();
DEFINE FIELD score:      Int            DEFAULT 0;
DEFINE FIELD status:     Enum<AccountStatus> DEFAULT AccountStatus.ACTIVE;

-- Node-level default overrides
DEFINE NODE TemporaryUser {
    id, name, email,
    status DEFAULT AccountStatus.PENDING
};

-- Edge field defaults
DEFINE EDGE Friendship {
    friend <-> (*),
    since: Date DEFAULT NOW(),
    active: Bool DEFAULT true
};

-- Extended cardinality
DEFINE EDGE Marriage   { spouse    <-> (2)       };
DEFINE EDGE Conference { attendee  <-  (10..500) };
DEFINE EDGE Adoption   { witness   <-  (0..1)    };

-- @cold decorator
DEFINE FIELD body: String? @cold;

-- @materialized (strongly preferred over bare @computed(TRAVERSE))
friend_count: Int @materialized @computed(TRAVERSE) {
    MATCH (this)-[:Friendship]-(f) RETURN COUNT(f)
};

-- Materialized view for cross-type queries
DEFINE MATERIALIZED VIEW PersonSearch
    FOR [Person, Employee, Admin]
    ON [LastName, FirstName, email]
    INDEX [LastName, FirstName];

-- Batch definitions
DEFINE FIELD [ id: UUID @required, name: String @required ];
DEFINE NODE  [
    RegularUser   { id, name, status },
    TemporaryUser { id, name, status DEFAULT AccountStatus.PENDING }
];
DEFINE EDGE  [ Friendship { friend <-> (*), since: Date DEFAULT NOW() } ];
DEFINE SCHEMA PersonGraph [ FIELD [...], NODE [...], EDGE [...] ];

-- Namespace modularization
DEFINE NAMESPACE Core.Game.Combat;
DEFINE NAMESPACE Core.Game.Combat [ ENUM [...], NODE [...] ];

-- Batch creation
CREATE NODE  [ alice:Person { ... }, bob:Person { ... } ];
CREATE [ NODE [ alice:Person { ... }, nova:Dog { ... } ], EDGE [ f:Owns { owner => alice, pet => nova } ] ];

-- Query blocks
MATCH   [ (p:Person), OPTIONAL (f:Person)-[:Friendship]-(p) ]
WHERE   [ p.age >= 18, p.status == AccountStatus.ACTIVE ]
WITH    [ p, COLLECT(f.name) AS friends ]
RETURN  [ name: p.name, friends: friends ]
ORDER BY friends DESC
LIMIT 10;
```

---

## 10. Version History Entry

```json
{
  "0.18": {
    "release_date": "TBD",
    "major_features": [
      "Normative storage architecture specification (Data-Oriented Design)",
      "Hybrid column/row storage model: fixed-width fields column-oriented, variable-width in separate heap",
      "Struct inline storage guarantee: no pointer indirection for embedded Struct fields",
      "Null bitmap representation: O(1) null checks via per-partition bit vector",
      "MANY role storage model: @ordered → dynamic array, @unordered → open-addressing hash set",
      "Edge dual-storage model: edge partition (column store) + role index tables (sorted node_id/edge_id pairs)",
      "Vector<N> SIMD alignment: 16/32-byte aligned, Struct-of-Arrays layout within partition",
      "@cold decorator: secondary-partition placement for large infrequently-accessed fields",
      "@materialized promoted to strongly preferred for @computed(TRAVERSE) in production schemas",
      "DEFINE MATERIALIZED VIEW: dedicated cross-type indexed partition for CROSS_TYPE queries",
      "Typed Enum variants: <INT>, <DECIMAL>, <STRING>, <FLAGS>",
      "FLAGS enum with uN backing type optimization and byte-boundary migration model",
      "Enum backing values explicitly prohibited as arithmetic operands across all typed variants",
      "Unit conversion canonical pattern: MassUnit node type with @readonly to_base_factor and @pure UDFs",
      "Field DEFAULT clause for write-time default values (global field definitions)",
      "Node-level DEFAULT override: per-type default that overrides global field default",
      "Edge field DEFAULT clause: DEFAULT on inline edge field definitions",
      "Three-level default resolution order: explicit > node/edge override > global > null > error",
      "@pure UDFs explicitly permitted in DEFAULT expressions",
      "@nondeterministic functions (NOW(), UUID()) explicitly permitted in DEFAULT expressions",
      "Extended cardinality: exact (N), unbounded (*), range (N..M)",
      "ONE and MANY formalized as named aliases for (1) and (*)",
      "Deprecation of ? role suffix in favor of (0..1)",
      "Cardinality bounds enforced on SET += and SET -= mutations, not only on CREATE",
      "Unified syntax model: comma-separated [...] array blocks; balanced-delimiter tokenizer guarantee",
      "Hoisting and five-pass validation for batch definition blocks",
      "Batch/multi-syntax: DEFINE FIELD, ROLE, NODE, EDGE, and mixed DEFINE [...] blocks",
      "DEFINE SCHEMA for named importable schema units with ALTER SCHEMA / VALIDATE SCHEMA",
      "Batch CREATE: CREATE NODE [...], CREATE EDGE [...], CREATE [NODE [...], EDGE [...]]",
      "CREATE [NODE, EDGE] shared variable scope for atomic cross-type creation",
      "Dot-hierarchy namespace modularization for multi-file schemas",
      "STRICT_MODE clarified as per-file, not per-namespace",
      "Namespace block form: DEFINE NAMESPACE Name [...]",
      "Query block syntax: MATCH [...], WHERE [...], WITH [...], RETURN [...]",
      "OPTIONAL as per-pattern modifier inside MATCH blocks",
      "Semantic grouping guideline for batch forms"
    ],
    "breaking_changes": [],
    "deprecations": [
      "role? <- (ONE) syntax — use role <- (0..1) instead. Removed in v0.19. [WARN-SCHEMA-002]"
    ],
    "new_error_codes": [
      "[1010] Namespace Collision",
      "[1011] Unresolved Import",
      "[1012] Circular Import",
      "[2060] Partial Enum Values",
      "[2061] Duplicate Enum Value",
      "[2062] Illegal Flags Value",
      "[2063] Flags Ceiling Exceeded",
      "[2064] Decimal Literal Required",
      "[2065] Unknown Enum Backing Type",
      "[2070] Invalid Default Expression",
      "[2071] Default Type Mismatch",
      "[2080] Invalid Cardinality Expression",
      "[3014] Role Cardinality Violated — on CREATE and on SET +=/-=",
      "[3015] Missing Required Field — non-nullable field with no default omitted from CREATE",
      "[6020] Materialized View Maintenance Failed",
      "[6021] Materialized View Stale"
    ],
    "new_warnings": [
      "[WARN-SCHEMA-002] Deprecated ? role suffix — use (0..1) cardinality instead",
      "[WARN-PERF-003] Cold field used in filter predicate — reclassify field or restructure query",
      "[WARN-PERF-004] Cross-type query falling back to partition scan — materialized view stale or missing"
    ]
  }
}
```
