; Indent blocks with braces
[
  (schema_body)
  (map_literal)
  (list_literal)
  (batch_statement)
  (alter)
  (map_clause)
  (defaults_clause)
] @indent

; Indent definition bodies
[
  (define_node)
  (define_edge)
  (define_enum)
  (define_struct)
  (define_trait)
] @indent

; Indent clause bodies
[
  (create_node_clause)
  (create_edge_clause)
  (merge_clause)
  (match_expression)
  (case_expression)
] @indent

; Indent query clauses
[
  (where_clause)
  (with_clause)
  (return_clause)
  (group_by_clause)
  (order_by_clause)
  (list_predicate)
] @indent

; Indent window functions
[
  (window_function)
] @indent

; Indent subqueries
[
  (subquery_expression)
] @indent

; Closing braces/brackets dedent
[
  "}"
  "]"
  ")"
] @outdent
