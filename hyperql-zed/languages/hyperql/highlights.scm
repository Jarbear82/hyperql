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

(postfix_expression
  [
    "IS NULL"
    "IS NOT NULL"
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
  "ON ERROR CONTINUE"
] @keyword

; Sorting & Windows
[
  "ASC"
  "DESC"
  "OVER"
  "PARTITION"
  "ROWS"
  "RANGE"
  "BETWEEN"
  "AND"
] @keyword


;;; --- OPERATORS ---

[
  "->"
  "<-"
  "<->"
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
  "??"
  "?."
  "=>"
] @operator

(node_pattern ":" @punctuation.delimiter)
(edge_pattern ":" @punctuation.delimiter)
(property_assignment "=" @punctuation.delimiter)
(property_access ["." "?."] @punctuation.delimiter)
(inferred_identifier (identifier) @variable.member)
(edge_pattern "*" @operator)
(range_literal ".." @operator)


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
(field_definition name: (identifier) @variable.member)
(define_role name: (identifier) @variable.special)
(role_definition name: (identifier) @variable.special)
(role_definition role_type: (identifier) @type)
(role_definition cardinality: _ @constant.builtin)
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
  "Path"
  "Decimal"
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
(field_definition type: (_) @type)
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
(named_constraint (identifier) @property)

; Role Bindings (Instance Creation)
(role_binding (identifier) @variable.special)


;;; --- FUNCTIONS & DECORATORS ---

; Generic
(function_call name: (identifier) @function.call)
(decorator (identifier) @attribute)
(decorator "@" @punctuation.special)

; Built-in Aggregate Functions
(function_call name: (identifier) @function.builtin
  (#match? @function.builtin "^(COUNT|SUM|AVG|MIN|MAX|COLLECT|STRING_AGG)$"))

; Built-in Window Functions
(function_call name: (identifier) @function.builtin
  (#match? @function.builtin "^(ROW_NUMBER|RANK|DENSE_RANK|NTILE|LAG|LEAD|FIRST_VALUE|LAST_VALUE)$"))

; Built-in String/Utility Functions
(function_call name: (identifier) @function.builtin
  (#match? @function.builtin "^(UPPER|LOWER|LEN|LENGTH|TRIM|SUBSTR|SUBSTRING|CONCAT|CONTAINS|STARTS_WITH|ENDS_WITH|NOW|ROUND|COALESCE|NULLIF|IF|UUID|LIST_INDEX|LIST_SLICE)$"))

; Built-in Type Conversion Functions
(function_call name: (identifier) @function.builtin
  (#match? @function.builtin "^(TO_STRING|TO_INT|TO_FLOAT|TO_BOOL|TO_DATE|TO_DECIMAL)$"))

; Built-in Math Functions
(function_call name: (identifier) @function.builtin
  (#match? @function.builtin "^(ABS|FLOOR|CEIL)$"))

; Built-in Date Functions
(function_call name: (identifier) @function.builtin
  (#match? @function.builtin "^(YEAR|MONTH|DAY|DATE|TIME|INTERVAL)$"))

; Built-in Graph Algorithms
(function_call name: (identifier) @function.builtin
  (#match? @function.builtin "^(SHORTEST_PATH|ALL_SHORTEST_PATHS|K_SHORTEST_PATHS|PAGERANK|BETWEENNESS_CENTRALITY|DEGREE_CENTRALITY|CONNECTED_COMPONENTS|LOUVAIN|TRIANGLE_COUNT|FIND_CYCLES|JACCARD_SIMILARITY|COSINE_SIMILARITY|VECTOR_SIMILARITY)$"))

; Built-in Decorators
(decorator (identifier) @attribute.builtin
  (#match? @attribute.builtin "^(computed|materialized|volatile|display|unique|required|readonly|optional|ordered|unordered|index|length)$"))


;;; --- LITERALS ---

(string_literal) @string
(escape_sequence) @string.escape
(integer_literal) @number
(decimal_literal) @number
(float_literal) @number.float
(boolean_literal) @boolean
(null_literal) @constant.builtin

(comment) @comment

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
