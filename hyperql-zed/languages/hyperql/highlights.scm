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
  "AND"
  "OR"
  "NOT"
  "OVER"
  "PARTITION"
] @keyword

(list_predicate
  [
    "ALL"
    "ANY"
    "NONE"
    "SINGLE"
  ] @keyword)

; Complex Phrases
[
  "READ UNCOMMITTED"
  "READ COMMITTED"
  "REPEATABLE READ"
  "SERIALIZABLE"
  "READ_UNCOMMITTED"
  "READ_COMMITTED"
  "REPEATABLE_READ"
] @keyword

[
  "IS NULL"
  "IS NOT NULL"
  "ON ERROR CONTINUE"
] @keyword

; Sorting
[
  "ASC"
  "DESC"
] @keyword

; System Commands
[
  "NODE"
  "EDGE"
] @keyword.control
(system_statement "TYPES" @keyword)
(system_statement "FIELDS" @keyword)
(system_statement "ROLES" @keyword)
(system_statement "SCHEMA" @keyword)


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

[
  "LIKE"
  "ILIKE"
  "MATCHES"
  "IMATCHES"
] @operator

(node_pattern ":" @punctuation.delimiter)
(edge_pattern ":" @punctuation.delimiter)
(property_assignment ":" @punctuation.delimiter)
(role_assignment "->" @punctuation.delimiter)
(property_access "." @punctuation.delimiter)
(edge_pattern "*" @operator)
(range_literal ".." @operator)

[
  "("
  ")"
  "["
  "]"
  "{"
  "}"
] @punctuation.bracket

[
  ","
  ";"
] @punctuation.delimiter


;;; --- TYPES & DEFINITIONS ---

; 1. Schema Definitions
(define_node name: (identifier) @type.definition)
(define_edge name: (identifier) @type.definition)
(define_struct name: (identifier) @type.definition)
(define_trait name: (identifier) @type.definition)
(define_enum name: (identifier) @type.definition)
(define_namespace name: (namespace_identifier) @namespace)
(define_index name: (identifier) @type.definition)

; 2. Field & Role Definitions
(define_field name: (identifier) @variable.member)
(define_role name: (identifier) @variable.special)
(role_definition name: (identifier) @variable.special)
(role_definition role_type: (identifier) @type)
(role_definition cardinality: _ @constant)
(role_definition direction: _ @operator)

; 3. Type Identifiers
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
  "Decimal"
  "Path"
  "Vector"
  "List"
  "Enum"
  "Struct"
] @type.builtin

(create_node_clause type: (dotted_identifier) @type)
(create_edge_clause type: (dotted_identifier) @type)
(merge_clause type: (dotted_identifier) @type)
(node_pattern type: (dotted_identifier) @type)
(edge_pattern type: (dotted_identifier) @type)
(define_field type: (_) @type)
(define_index type: (identifier) @type)


;;; --- VARIABLES & PROPERTIES ---

(variable) @variable.parameter
(identifier) @variable

; Pattern variables
(node_pattern variable: (identifier) @variable.parameter)
(edge_pattern variable: (identifier) @variable.parameter)
(match_path_clause path_var: (identifier) @variable.parameter)

; Create/Merge variables
(create_node_clause variable: (identifier) @variable.parameter)
(create_edge_clause variable: (identifier) @variable.parameter)
(merge_clause variable: (identifier) @variable.parameter)
(merge_object_clause variable: (identifier) @variable.parameter)

; Fields (Usage)
(property_assignment (identifier) @property)
(property_access property: (identifier) @property)
(property_access object: (identifier) @variable)

; Roles (Usage)
(role_assignment (identifier) @variable.special)


;;; --- FUNCTIONS & DECORATORS ---

; Generic
(function_call name: (identifier) @function.call)
(decorator (identifier) @attribute)

; Built-in Aggregate Functions
(function_call name: (identifier) @function.builtin
  (#match? @function.builtin "^(COUNT|SUM|AVG|MIN|MAX|COLLECT|STRING_AGG)$"))

; Built-in Window Functions
(function_call name: (identifier) @function.builtin
  (#match? @function.builtin "^(ROW_NUMBER|RANK|DENSE_RANK|NTILE|LAG|LEAD|FIRST_VALUE|LAST_VALUE)$"))

; Built-in String/Utility Functions
(function_call name: (identifier) @function.builtin
  (#match? @function.builtin "^(UPPER|LOWER|LEN|LENGTH|TRIM|SUBSTR|SUBSTRING|CONCAT|CONTAINS|STARTS_WITH|ENDS_WITH|NOW|ROUND|COALESCE|IF)$"))

; Built-in Type Conversion Functions
(function_call name: (identifier) @function.builtin
  (#match? @function.builtin "^(TO_STRING|TO_INT|TO_FLOAT|TO_BOOL|TO_DATE)$"))

; Built-in Graph Algorithms
(function_call name: (identifier) @function.builtin
  (#match? @function.builtin "^(SHORTEST_PATH|PAGERANK|BETWEENNESS_CENTRALITY|LOUVAIN|CONNECTED_COMPONENTS|JACCARD_SIMILARITY)$"))

; Built-in Decorators
(decorator (identifier) @attribute.builtin
  (#match? @attribute.builtin "^(computed|materialized|volatile|display|unique|required|readonly|optional|ordered|unordered|index|length)$"))


;;; --- LITERALS ---

(string_literal) @string
(escape_sequence) @string.escape
(integer_literal) @number
(float_literal) @number.float
(boolean_literal) @boolean
(null_literal) @constant.builtin

(comment) @comment

; Special wildcard in function calls
(function_call "*" @operator)


;;; --- CLAUSES & PROJECTIONS ---



; Import
(import_clause (string_literal) @string.special.path)



; Index hint
(use_index_hint (identifier) @variable.special)

; Map entries
(map_entry (identifier) @property)

; Cardinality literals
[
  "(ONE)"
  "(MANY)"
] @constant
