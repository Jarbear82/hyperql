;;; --- KEYWORDS & CLAUSES ---

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
  "EXISTS"
  "IN"
  "IS"
] @keyword

(list_predicate 
  [
    "ALL" 
    "ANY" 
    "NONE" 
    "SINGLE"
  ] @keyword)

(binary_expression 
  [
    "IS NULL" 
    "IS NOT NULL" 
    "LIKE" 
    "ILIKE" 
    "MATCHES" 
    "IMATCHES"
  ] @keyword)

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


;;; --- OPERATORS ---

[
  "->"
  "<-"
  "+="
  "-="
  "=="
  "!="
  ">="
  "<="
  "&&"
  "||"
  "!"
  "="
  "+"
  "-"
  "*"
  "/"
  "%"
  "<"
  ">"
] @operator

(node_pattern ":" @punctuation.delimiter)
(edge_pattern ":" @punctuation.delimiter)
(property_assignment ":" @punctuation.delimiter)
(property_access "." @punctuation.delimiter)
(edge_pattern "*" @operator)


;;; --- TYPES & DEFINITIONS ---

; 1. Schema Definitions
(define_node name: (identifier) @type.definition)
(define_edge name: (identifier) @type.definition)
(define_struct name: (identifier) @type.definition)
(define_trait name: (identifier) @type.definition)
(define_enum name: (identifier) @type.definition)
(define_namespace name: (namespace_identifier) @namespace)

; 2. Field & Role Definitions
(define_field name: (identifier) @function)
(define_role name: (identifier) @variable.special)
(role_definition name: (identifier) @variable.special)
(role_definition role_type: (identifier) @type)
(role_definition cardinality: _ @constant)
(role_definition direction: _ @operator)

; 3. Type Identifiers
[
  "String" "Int" "Int32" "Float" "Bool" "Date" 
  "UUID" "Interval" "Time" "Decimal" "Path" 
  "Vector" "List" "Enum" "Struct"
] @type.builtin

(create_node_clause type: (dotted_identifier) @type)
(create_edge_clause type: (dotted_identifier) @type)
(node_pattern type: (dotted_identifier) @type)
(edge_pattern type: (dotted_identifier) @type)
(define_field type: (_) @type)


;;; --- VARIABLES & PROPERTIES ---

(variable) @variable
(identifier) @variable

; Fields (Usage)
(property_assignment (identifier) @property)
(property_access property: (identifier) @property)

; Roles (Usage)
(role_assignment (identifier) @variable.special)


;;; --- FUNCTIONS & DECORATORS ---

; Generic
(function_call name: (identifier) @function.method)
(decorator (identifier) @attribute)

; Built-in Functions (Overrides generic)
(function_call name: (identifier) @function.builtin
  (#match? @function.builtin "^(COUNT|SUM|AVG|MIN|MAX|COLLECT|STRING_AGG)$"))

(function_call name: (identifier) @function.builtin
  (#match? @function.builtin "^(ROW_NUMBER|RANK|DENSE_RANK|NTILE|LAG|LEAD|FIRST_VALUE|LAST_VALUE)$"))

(function_call name: (identifier) @function.builtin
  (#match? @function.builtin "^(UPPER|LOWER|LEN|TRIM|SUBSTR|CONCAT|CONTAINS|STARTS_WITH|ENDS_WITH|NOW|ROUND)$"))

(function_call name: (identifier) @function.builtin
  (#match? @function.builtin "^(SHORTEST_PATH|PAGERANK|BETWEENNESS_CENTRALITY|LOUVAIN|CONNECTED_COMPONENTS)$"))

; Built-in Decorators (Overrides generic)
(decorator (identifier) @attribute.builtin
  (#match? @attribute.builtin "^(computed|materialized|volatile|display|unique|required|readonly|optional|ordered|unordered|index|length)$"))


;;; --- LITERALS ---

(string_literal) @string
(escape_sequence) @string.escape
(integer_literal) @number
(float_literal) @number
(boolean_literal) @boolean
(null_literal) @constant

(comment) @comment
