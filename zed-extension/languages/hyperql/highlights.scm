; Keywords
"DEFINE" @keyword
"NAMESPACE" @keyword
"ENUM" @keyword
"FIELD" @keyword
"ROLE" @keyword
"STRUCT" @keyword
"TRAIT" @keyword
"NODE" @keyword
"EDGE" @keyword
"INDEX" @keyword
"MATCH" @keyword
"CREATE" @keyword
"RETURN" @keyword
"SET" @keyword
"DELETE" @keyword
"WHERE" @keyword
"WITH" @keyword
"ORDER" @keyword
"BY" @keyword
"LIMIT" @keyword
"SKIP" @keyword
"UNWIND" @keyword
"UNION" @keyword
"USE" @keyword
"CASE" @keyword
"WHEN" @keyword
"THEN" @keyword
"ELSE" @keyword
"END" @keyword
"DISTINCT" @keyword
"OPTIONAL" @keyword
"MERGE" @keyword
"ON" @keyword
"DETACH" @keyword
"REMOVE" @keyword
"GROUP" @keyword
"IMPORT" @keyword
"AS" @keyword
"SHOW" @keyword
"EXPLAIN" @keyword
"ANALYZE" @keyword
"BEGIN" @keyword
"MIGRATE" @keyword
"VALIDATE" @keyword
"ALTER" @keyword
"ADD" @keyword
"DROP" @keyword
"RENAME" @keyword
"TO" @keyword
"MAP" @keyword
"DEFAULTS" @keyword
"EXTENDS" @keyword
"ABSTRACT" @keyword
"STRICT_MODE" @keyword
"ALLOWS" @keyword
"ISOLATION" @keyword
"LEVEL" @keyword
"BATCH" @keyword
"WEIGHT" @keyword
"USING" @keyword
"SUM" @keyword
"MAX" @keyword
"MIN" @keyword
"AVG" @keyword
"CROSS_TYPE" @keyword
"PATH" @keyword
"ALL" @keyword
"ANY" @keyword
"NONE" @keyword
"SINGLE" @keyword
"COMMIT" @keyword
"ROLLBACK" @keyword
"OBJECT" @keyword

; Transaction & Isolation Phrases
"READ UNCOMMITTED" @keyword
"READ COMMITTED" @keyword
"REPEATABLE READ" @keyword
"SERIALIZABLE" @keyword
"ON ERROR CONTINUE" @keyword

; Window Functions
"OVER" @keyword
"PARTITION" @keyword

; Sorting
"ASC" @keyword
"DESC" @keyword

; Built-in Types (Strings in the grammar)
"String" @type
"Int" @type
"Int32" @type
"Float" @type
"Bool" @type
"Date" @type
"UUID" @type
"Interval" @type
"Time" @type
"Decimal" @type
"Path" @type
"Vector" @type
"List" @type
"Enum" @type
"Struct" @type

; Type Captures in Nodes
(define_field type: (_) @type)
(create_node_clause type: (identifier) @type)
(create_edge_clause type: (identifier) @type)
(node_pattern type: (identifier) @type)
(edge_pattern type: (identifier) @type)

; Functions
(function_call name: (identifier) @function)

; Literals
(string_literal) @string
(integer_literal) @number
(float_literal) @number
(boolean_literal) @boolean
(null_literal) @constant

; Properties & Variables
(property_assignment (identifier) @property)
(role_assignment (identifier) @property)
(assignment_expression (property_access property: (identifier) @property))
(property_access property: (identifier) @property)
(variable) @variable

; Identifiers (Fallback)
(identifier) @variable

; Comments
(comment) @comment
