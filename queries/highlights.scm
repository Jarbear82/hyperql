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
  "ON"
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
; Decorators (Fixed)
; ==========================================

; Both the symbol and the identifier are now punctuation.special
; This forces them to be the same color (Purple in most themes)
(decorator "@" @punctuation.special)
(decorator (identifier) @punctuation.special)

; ==========================================
; Types
; ==========================================

; CHANGED: Mapped built-ins to @support.type or @constant.builtin
; This usually forces a different color than standard types/properties.
[
  "String"
  "Int"
  "Int32"
  "Float"
  "Bool"
  "Date"
  "UUID"
  "Interval"
  "Time"
  "Path"
  "Decimal"
  "Vector"
  "List"
  "Enum"
  "Struct"
] @constant.builtin

; Generic Type names (User defined)
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

; Built-in functions
; (Placed higher up to ensure DATE() is seen as a function, not a constant)
(function_call
  name: (identifier) @function.builtin
  (#match? @function.builtin "^(COUNT|SUM|AVG|MIN|MAX|COLLECT|STRING_AGG|COALESCE|NULLIF|TO_STRING|TO_INT|TO_FLOAT|TO_DECIMAL|UPPER|LOWER|LEN|TRIM|SUBSTR|CONCAT|CONTAINS|STARTS_WITH|ENDS_WITH|ABS|ROUND|FLOOR|CEIL|NOW|YEAR|MONTH|DAY|DATE|TIME|INTERVAL|LIST_INDEX|LIST_SLICE|SHORTEST_PATH|ALL_SHORTEST_PATHS|K_SHORTEST_PATHS|PAGERANK|BETWEENNESS_CENTRALITY|DEGREE_CENTRALITY|CONNECTED_COMPONENTS|LOUVAIN|TRIANGLE_COUNT|FIND_CYCLES|JACCARD_SIMILARITY|COSINE_SIMILARITY|ROW_NUMBER|RANK|DENSE_RANK|NTILE|LAG|LEAD|FIRST_VALUE|LAST_VALUE)$")
)

(function_call name: (identifier) @function)

; ==========================================
; Properties & Fields
; ==========================================

; --- DEFINITIONS ---

; Field Definitions: DEFINE FIELD name: String
(define_field name: (identifier) @property)
(field_definition name: (identifier) @property)
(define_struct field: (identifier) @property)
(define_trait field: (identifier) @property)

; Role Definitions: DEFINE ROLE name ALLOWS...
(define_role name: (identifier) @variable.parameter)

; Role Definitions inside Schema: husband <- (ONE)
(role_definition name: (identifier) @variable.parameter)

; Bare identifiers in schema (e.g. firstName,) default to property
; (We can't distinguish roles from fields here without the operators, so blue is safe)
(schema_body (identifier) @property)


; --- USAGE / ASSIGNMENT ---

; Property Access: user.name
(property_access property: (identifier) @property)

; Field Assignment: name = "Value"
(property_assignment name: (identifier) @property)
(property_assignment value: (identifier) @variable)

; Role Binding: husband => doug
; (This makes the key "husband" Orange/Italic to match the => operator intent)
(role_binding name: (identifier) @variable.parameter)
(role_binding value: (identifier) @variable)

; Inferred identifiers (e.g. .MALE)
(inferred_identifier (identifier) @constant)

; Named constraints inside blocks
(named_constraint (identifier) @property)

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

[
  "(ONE)"
  "(MANY)"
] @constant.builtin

; Enum values definition
(define_enum value: (identifier) @constant)

; ALL_CAPS identifiers as constants (MOVED TO BOTTOM)
; This now acts as a fallback. It will only color something Purple
; if it wasn't already caught as a Function, Type, or Property.
((identifier) @constant (#match? @constant "^[A-Z][A-Z0-9_]+$"))

; ==========================================
; Comments & Punctuation
; ==========================================

(comment) @comment

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
