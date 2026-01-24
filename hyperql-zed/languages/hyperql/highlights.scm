;;; --- KEYWORDS & SYNTAX ---
[
  "DEFINE"
  "NAMESPACE"
  "ENUM"
  "FIELD"
  "ROLE"
  "STRUCT"
  "TRAIT"
  "NODE"
  "EDGE"
  "INDEX"
  "MATCH"
  "CREATE"
  "RETURN"
  "SET"
  "DELETE"
  "WHERE"
  "WITH"
  "ORDER"
  "BY"
  "LIMIT"
  "SKIP"
  "UNWIND"
  "UNION"
  "USE"
  "CASE"
  "WHEN"
  "THEN"
  "ELSE"
  "END"
  "DISTINCT"
  "OPTIONAL"
  "MERGE"
  "ON"
  "DETACH"
  "REMOVE"
  "GROUP"
  "IMPORT"
  "AS"
  "SHOW"
  "EXPLAIN"
  "ANALYZE"
  "BEGIN"
  "COMMIT"
  "ROLLBACK"
  "MIGRATE"
  "VALIDATE"
  "ALTER"
  "ADD"
  "DROP"
  "RENAME"
  "TO"
  "MAP"
  "DEFAULTS"
  "EXTENDS"
  "ABSTRACT"
  "STRICT_MODE"
  "ALLOWS"
  "ISOLATION"
  "LEVEL"
  "BATCH"
  "WEIGHT"
  "USING"
  "SUM"
  "MAX"
  "MIN"
  "AVG"
  "CROSS_TYPE"
  "PATH"
  "OBJECT"
] @keyword

; Complex Phrases
[
  "READ UNCOMMITTED"
  "READ COMMITTED"
  "REPEATABLE READ"
  "SERIALIZABLE"
  "ON ERROR CONTINUE"
] @keyword

; Sorting & Windows
[
  "ASC"
  "DESC"
  "OVER"
  "PARTITION"
] @keyword

;;; --- DEFINITIONS (Distinct from Usage) ---

; 1. Field Definitions (e.g. DEFINE FIELD name)
; Using @function makes them stand out from standard properties
(define_field 
  name: (identifier) @function)

; 2. Role Definitions (e.g. DEFINE ROLE name)
; Using @type.builtin makes them distinct from fields
(define_role 
  name: (identifier) @type.builtin)

; 3. Structure Definitions (Nodes, Edges, Structs)
(define_node name: (identifier) @type.definition)
(define_edge name: (identifier) @type.definition)
(define_struct name: (identifier) @type.definition)
(define_trait name: (identifier) @type.definition)
(define_enum name: (identifier) @type.definition)
(define_namespace name: (namespace_identifier) @namespace)

;;; --- TYPES ---

; Built-in types (captured as strings in your grammar?)
[
  "String" "Int" "Int32" "Float" "Bool" "Date" 
  "UUID" "Interval" "Time" "Decimal" "Path" 
  "Vector" "List" "Enum" "Struct"
] @type.builtin

; Type identifiers in clauses
(create_node_clause type: (identifier) @type)
(create_edge_clause type: (identifier) @type)
(node_pattern type: (identifier) @type)
(edge_pattern type: (identifier) @type)
(define_field type: (_) @type)

;;; --- VARIABLES & PROPERTIES ---

; 1. Fields (Usage) - Standard Property Color
(property_assignment (identifier) @property)
(property_access property: (identifier) @property)

; 2. Roles (Usage) - Distinct "Special" Color
; Used in edge creation: role -> value
(role_assignment (identifier) @variable.special)
; Used in definition: role: RoleType
(role_definition name: (identifier) @variable.special)

; 3. Standard Variables
(variable) @variable
(identifier) @variable

;;; --- SPECIAL FEATURES ---

; Decorators (e.g. @unique)
(decorator) @attribute

; Cardinality (e.g. (ONE), (MANY))
(role_definition cardinality: _ @constant)

; Functions
(function_call name: (identifier) @function.method)

;;; --- LITERALS ---
(string_literal) @string
(integer_literal) @number
(float_literal) @number
(boolean_literal) @boolean
(null_literal) @constant

; Comments
(comment) @comment