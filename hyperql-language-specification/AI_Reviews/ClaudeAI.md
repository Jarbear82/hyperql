# HyperQL 0.17 Review — Handoff Summary
*Generated 2026-03-02 | Based on spec + 4-AI cross-review synthesis*

---

## Context
Full spec reviewed by Claude, Grok, Gemini, and ChatGPT. Claude and Grok found substantive issues; Gemini and ChatGPT produced mostly affirmative summaries without identifying defects. The synthesis combined all four lenses into a unified, prioritized issue list.

**Overall verdict:** Genuinely strong spec with real innovations. Not ready to ship as-is. ~15 targeted fixes would make it implementation-ready.

---

## Critical Issues (Blocking — Fix Before Implementation)

### 1. `@readonly` Name Collision
- Used for **field decorator** ("property is immutable after creation") AND **function purity decorator** ("may perform graph traversal")
- Same token, different scopes, different semantics — parser cannot resolve
- **Fix:** Rename field decorator to `@immutable`

### 2. MATCH Evaluation Semantics Undefined *(Grok)*
- No definition of: bag vs. set semantics, row expansion rules, duplicate generation, traversal ordering, null-producing behavior outside OPTIONAL MATCH
- Multiple sequential MATCHes have undefined join behavior
- **Fix:** Add a formal "MATCH Execution Model" section with pseudocode

### 3. MERGE Resolution Algorithm Undefined *(Grok)*
- Candidate selection priority, multi-match behavior, lock acquisition order, and uniqueness violation timing are all unspecified
- MERGE is historically the hardest graph DB operator to implement correctly
- **Fix:** Provide pseudocode-level algorithm for both property-based and role-based MERGE paths

### 4. `IS` Disambiguation Operator Never Defined
- Referenced in error [2020] and role constraint rules: "fields must exist on ALL allowed types unless disambiguated with IS operator"
- No syntax, no semantics, no examples anywhere in the spec
- **Fix:** Add formal definition to expression language section

### 5. Hyperedge MANY-Role Traversal Expansion Undefined *(Grok)*
- Spec states MANY returns ordered lists but doesn't define how traversal converts collections → rows
- Directly affects query planner and result cardinality
- **Fix:** Define expansion strategy, ordering guarantees, and duplicate handling for MANY-role traversal

---

## Significant Issues (Fix Before Implementation)

### 6. `DEFINE ROLE` Constraint Syntax Contradiction
- Unified multi-type constraints (`ALLOWS [Person, AI]`) show `this.field` notation
- But multi-type resolution rules say `this` is ambiguous without `Type.field` notation
- The `IS` operator is supposed to resolve this but is never defined (see #4)
- **Fix:** Resolve `this` semantics for unified multi-type constraints; define `IS` operator

### 7. `MATCH` Keyword Dual-Use Parsing Ambiguity
- `MATCH` is both the primary query clause AND a conditional expression function
- `RETURN MATCH p.Status { ACTIVE => "..." }` vs. `MATCH (p:Person) RETURN p`
- No parser disambiguation rule is defined
- **Fix:** Rename the conditional expression to `SWITCH` or `WHEN`, or define explicit parsing context rules

### 8. Materialized Property Invalidation Model Incomplete *(Grok + Claude)*
- Spec says "@materialized recomputes on writes affecting traversal pattern" but doesn't define:
  - How the dependency graph is tracked
  - Invalidation propagation rules
  - Cycle handling
  - Batch recomputation ordering
- **Fix:** Add dependency tracking model to the @materialized decorator specification

### 9. Cost Model Inputs Missing *(Grok)*
- Cost-based optimizer is referenced throughout but lacks:
  - Statistics definition and collection model
  - Selectivity estimation formula
  - Path expansion cost model
  - Hyperedge traversal cost
- **Fix:** Add a "Planner Statistics Model" subsection to Part 3

### 10. `CROSS_TYPE` Has No Formal Definition
- Used in storage architecture notes and query examples
- Never defined as a keyword in the read clauses section
- **Fix:** Add formal CROSS_TYPE entry to Part 4 read clauses

---

## Minor Issues (Fix Before v1.0)

| # | Issue | Fix |
|---|---|---|
| 11 | `SET +=` used for two different operations (bulk property update AND atomic role append) — listed as separate entries but same token | Document as explicit syntactic disambiguation rule |
| 12 | Missing from built-in functions: `TYPE()`, `VECTOR_SIMILARITY()`, and PATH object properties (`.nodes`, `.edges`, `.cost`, `.length`, `.roles`) | Add to Part 2 built-in functions and Part 1 data types |
| 13 | `@deferred` constraint behavior underspecified — no rules for mutually deferred constraints or error reporting | Expand @deferred decorator spec with circular dependency resolution rules |
| 14 | Namespace import conflict resolution undefined — aliasing, shadow precedence, version pinning | Add conflict resolution rules to IMPORT keyword definition |
| 15 | `@optional` deprecation path incomplete — `?` suffix documented for DEFINE EDGE roles but not for DEFINE ROLE definitions | Clarify whether `?` applies at the role definition or edge definition level |

---

## Recommendations

1. **Add an "Execution Semantics" section** (new Part 3.5 or appendix) covering MATCH evaluation, row expansion, MERGE algorithm, and hyperedge traversal. This is the single highest-leverage action.
2. **Rename `@readonly` field decorator to `@immutable`** — one-line fix that eliminates a genuine parser collision.
3. **Rename or disambiguate the `MATCH` conditional expression** — `SWITCH` is the simplest alternative.
4. **Define the `IS` polymorphic disambiguation operator** — it's referenced as if it exists but has zero specification.
5. **Add missing built-in functions** to the reference section — `TYPE()` and `VECTOR_SIMILARITY()` both appear in examples without definitions.

---

## Suggested Next Steps (In Order)

- [ ] **Step 1:** Resolve the `@readonly` collision and `MATCH` keyword ambiguity — these are spec-level blockers that affect everything downstream
- [ ] **Step 2:** Write the Execution Semantics section (MATCH model + MERGE algorithm) — unblocks engine implementation
- [ ] **Step 3:** Define the `IS` operator and fix `DEFINE ROLE` unified constraint syntax
- [ ] **Step 4:** Expand `@materialized` invalidation model and add cost model inputs to Part 3
- [ ] **Step 5:** Add missing built-in function entries and `CROSS_TYPE` formal definition
- [ ] **Step 6:** Address the minor issues table above
- [ ] **Step 7:** Re-review Part 7 error codes to ensure all new/changed behavior has corresponding error codes

---

## What Was Agreed Across All Four AI Reviews (Do Not Change)
- Hyperedge + role model is the spec's strongest innovation — keep as-is
- Three-level constraint system (Node → Role → Edge) is correct and well-ordered
- Write-time-only validation with zero read overhead is the right architecture
- Composable polymorphism via global DEFINE FIELD correctly eliminates diamond conflicts
- Version history and migration guide are high quality — expand, don't restructure
