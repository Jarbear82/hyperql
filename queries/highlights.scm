; ==========================================
; Keywords
; ==========================================

[
  "DEFINE"
  "NAMESPACE"
  "FIELD"
  "ROLE"
  "NODE"
  "EDGE"
  "STRUCT"
  "TRAIT"
  "ENUM"
  "INDEX"
  "ABSTRACT"
  "EXTENDS"
  "STRICT_MODE"
  "VALIDATE"
  "MIGRATION"
  "MIGRATE"
  "ALTER"
  "ADD"
  "DROP"
  "RENAME"
  "TO"
  "MAP"
  "DEFAULTS"
  "SHOW"
  "EXPLAIN"
  "ANALYZE"
  "VERBOSE"
  "JSON"
  "BATCH"
  "BEGIN"
  "COMMIT"
  "ROLLBACK"
  "SET"
  "ISOLATION"
  "LEVEL"
  "ON ERROR CONTINUE"
  "IMPORT"
  "AS"
  "MATCH"
  "OPTIONAL"
  "CROSS_TYPE"
  "WHERE"
  "WITH"
  "RETURN"
  "DISTINCT"
  "ORDER"
  "BY"
  "ASC"
  "DESC"
  "LIMIT"
  "SKIP"
  "GROUP"
  "UNION"
  "ALL"
  "UNWIND"
  "USE"
  "WEIGHT"
  "USING"
  "CASE"
  "WHEN"
  "THEN"
  "ELSE"
  "END"
  "IF"
  "CREATE"
  "DELETE"
  "DETACH"
  "REMOVE"
  "MERGE"
  "OBJECT"
  "ALLOWS"
  "TRAVERSE"
  "OVER"
  "PARTITION"
  "ROWS"
  "RANGE"
  "BETWEEN"
  "PRECEDING"
  "FOLLOWING"
  "CURRENT"
  "ROW"
  "UNBOUNDED"
] @keyword

(constraint_block "constraints" @keyword)

; ==========================================
; Types
; ==========================================

; Built-in types found in _data_type
(
  (_data_type) @type.builtin
  (#match? @type.builtin "^(String|Int|Int32|Float|Bool|Date|UUID|Interval|Time|Path|Decimal|Vector|List|Enum|Struct)$")
)

; Generic Type names (User defined or complex)
(define_node name: (identifier) @type)
(define_edge name: (identifier) @type)
(define_enum name: (identifier) @type)
(define_struct name: (identifier) @type)
(define_trait name: (identifier) @type)
(define_index type: (identifier) @type)

; Type references in clauses
(create_node_clause type: (dotted_identifier) @type)
(create_edge_clause type: (dotted_identifier) @type)
(merge_clause type: (dotted_identifier) @type)
(node_pattern type: (dotted_identifier) @type)
(edge_pattern type: (dotted_identifier) @type)
(define_field type: (_) @type)
(field_definition type: (_) @type)
(extends_clause (identifier) @type)
(validate_migration (identifier) @type)
(migrate (identifier) @type)

; ==========================================
; Functions
; ==========================================

; Built-in functions specified in HyperQL 0.16 spec
(function_call
  name: (identifier) @function.builtin
  (#match? @function.builtin "^(COUNT|SUM|AVG|MIN|MAX|COLLECT|STRING_AGG|COALESCE|NULLIF|TO_STRING|TO_INT|TO_FLOAT|TO_DECIMAL|UPPER|LOWER|LEN|TRIM|SUBSTR|CONCAT|CONTAINS|STARTS_WITH|ENDS_WITH|ABS|ROUND|FLOOR|CEIL|NOW|YEAR|MONTH|DAY|DATE|TIME|INTERVAL|LIST_INDEX|LIST_SLICE|SHORTEST_PATH|ALL_SHORTEST_PATHS|K_SHORTEST_PATHS|PAGERANK|BETWEENNESS_CENTRALITY|DEGREE_CENTRALITY|CONNECTED_COMPONENTS|LOUVAIN|TRIANGLE_COUNT|FIND_CYCLES|JACCARD_SIMILARITY|COSINE_SIMILARITY|ROW_NUMBER|RANK|DENSE_RANK|NTILE|LAG|LEAD|FIRST_VALUE|LAST_VALUE)$")
)

; Generic function calls
(function_call name: (identifier) @function)

; ==========================================
; Variables
; ==========================================

; Variable declaration contexts
(match_path_clause path_var: (identifier) @variable)
(create_node_clause variable: (identifier) @variable)
(create_edge_clause variable: (identifier) @variable)
(merge_clause variable: (identifier) @variable)
(merge_object_clause variable: (identifier) @variable)
(node_pattern variable: (identifier) @variable)
(edge_pattern variable: (identifier) @variable)
(unwind_clause (identifier) @variable)
(import_clause (identifier) @variable)

; $variable syntax
(variable (identifier) @variable)

; "this" builtin
((identifier) @variable.builtin (#eq? @variable.builtin "this"))

; ==========================================
; Properties & Fields
; ==========================================

; Definition contexts
(define_field name: (identifier) @property)
(field_definition name: (identifier) @property)
(define_struct field: (identifier) @property)
(define_trait field: (identifier) @property)

; Property access
(property_access property: (identifier) @property)
(property_assignment (identifier) @property)
(named_constraint (identifier) @property)

; Inferred identifiers (e.g. .MALE)
(inferred_identifier (identifier) @property)

; Roles (semantically properties/edges)
(define_role name: (identifier) @variable.parameter) ; Using variable.parameter to distinguish definition
(role_definition name: (identifier) @property)
(role_binding (identifier) @property)

; ==========================================
; Decorators / Attributes
; ==========================================

(decorator "@" @punctuation.special)
(decorator (identifier) @attribute)

; ==========================================
; Literals & Constants
; ==========================================

(string_literal) @string
(escape_sequence) @string.escape
(integer_literal) @number
(float_literal) @number
(decimal_literal) @number
(boolean_literal) @boolean
(null_literal) @constant.builtin
(map_literal) @embedded

; Enum values definition
(define_enum value: (identifier) @constant)

; ALL_CAPS identifiers as constants
((identifier) @constant (#match? @constant "^[A-Z][A-Z0-9_]+$"))

; ==========================================
; Comments
; ==========================================

(comment) @comment

; ==========================================
; Operators & Punctuation
; ==========================================

[
  "+" "-" "*" "/" "%"
  "<" ">" "<=" ">="
  "==" "=" "!=" "!"
  "&&" "||" "AND" "OR" "NOT"
  "??" "?."
  "IS" "IS NULL" "IS NOT NULL"
  "LIKE" "ILIKE" "MATCHES" "IMATCHES"
  "IN" "EXISTS"
  "=>" "->" "<-" "<->" "+=" "-="
] @operator

[
  "(" ")"
  "[" "]"
  "{" "}"
] @punctuation.bracket

[
  ";"
  ","
  "."
  ":"
  "?"
] @punctuation.delimiter