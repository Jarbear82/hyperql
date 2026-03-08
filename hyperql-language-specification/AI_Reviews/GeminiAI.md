Here is a concise summary of our review synthesis so you can pick up exactly where we left off.

### **Executive Recap**

HyperQL 0.17 is an outstanding, structurally robust blueprint for a next-generation hypergraph database. Its schema model (hyperedges, roles, composable polymorphism) and write-time constraints are production-ready. However, it currently lacks the rigorous execution and parsing definitions required for an engineering team to actually build the engine.

---

### **Critical Issues (Blockers)**

**1. Execution Engine Gaps (Semantics)**

* **`MATCH` Underspecified:** Lacks formal definitions for pattern binding algorithms, evaluation order, duplicate row handling (bag vs. set semantics), and traversal ordering.
* **Hyperedge Expansion (`MANY` Roles):** No defined strategy for how the engine converts collection iteration into planner rows when traversing multi-party roles.
* **`MERGE` Resolution Algorithms:** Missing the pseudo-code for candidate selection priority, multi-match resolution, and lock acquisition order (historically the hardest graph operator to implement).
* **`@materialized` Updates:** Missing dependency graph tracking and cycle-handling rules for when/how materialized computed fields invalidate and recalculate.

**2. Parser & Syntax Collisions**

* **The `@readonly` Collision:** Used identically for two different concepts: making a field immutable, and marking a UDF as allowing graph traversal.
* **The `MATCH` Ambiguity:** Used as both the main graph traversal clause (`MATCH (p:Person)`) and a conditional expression (`MATCH expr { pattern => value }`). This will break parsers in `RETURN` statements.
* **Operator Overloading (`SET +=`):** Used simultaneously for bulk object updates and appending items to a `MANY` role collection.
* **Missing Formal Definitions:** Keywords/features like `CROSS_TYPE`, the `PATH` object properties, `VECTOR_SIMILARITY`, and the polymorphic `IS` disambiguation operator appear in examples but lack strict syntax definitions.

---

### **Immediate Recommendations**

1. **Resolve Lexical Collisions:** Rename the field-level `@readonly` to `@immutable`. Consider renaming the conditional `MATCH` expression (e.g., to a `CASE`-variant or `SWITCH`) to protect the primary query clause.
2. **Define the Missing Primitives:** Add formal syntax blocks for `CROSS_TYPE`, `PATH` properties, and the `IS` operator.
3. **Draft an "Execution Semantics" Chapter:** This is the biggest missing piece. It must contain the step-by-step algorithms for how the planner executes `MATCH`, `MERGE`, and hyperedge expansions.

---

### **Next Steps for When You Return**

When you are ready to resume, let me know which of these you'd like to tackle first:

* **Option A:** *Draft the Execution Semantics.* (I can generate the missing step-by-step algorithms for `MATCH` and `MERGE` behavior).
* **Option B:** *Create a Syntax Disambiguation Proposal.* (I can map out the exact parser collisions and propose clean syntax alternatives for the next spec version).
* **Option C:** *Flesh out the missing formal definitions* (Writing the specs for `CROSS_TYPE`, `IS`, and `PATH`).
