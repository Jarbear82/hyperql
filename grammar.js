module.exports = grammar({
  name: "hyperql",

  extras: ($) => [$.comment, /\s/],

  // Prioritize specific keywords to prevent them being lexed as generic identifiers
  word: ($) => $.identifier,

  // Explicitly handle the ambiguity where a new clause (like IMPORT)
  // could either continue the current statement or start a new one.
  // conflicts: ($) => [[$.manipulation_statement]],

  rules: {
    // Top-level source file can contain multiple statements
    source_file: ($) => repeat($._statement),

    _statement: ($) =>
      choice(
        $.definition_statement,
        $.manipulation_statement,
        $.migration_statement,
        $.system_statement,
        $.batch_statement,
        $.begin_transaction,
      ),

    // ==========================================
    // 1. Schema Definitions (DDL)
    // ==========================================

    definition_statement: ($) =>
      choice(
        $.define_namespace,
        $.define_enum,
        $.define_field,
        $.define_role,
        $.define_struct,
        $.define_trait,
        $.define_node,
        $.define_edge,
        $.define_index,
      ),

    define_namespace: ($) =>
      seq(
        "DEFINE",
        "NAMESPACE",
        field("name", $.namespace_identifier),
        optional(seq("STRICT_MODE", "=", $.boolean_literal)),
        ";"
      ),

    define_enum: ($) =>
      seq(
        "DEFINE",
        "ENUM",
        field("name", $.identifier),
        "{",
        commaSep($.identifier),
        "}",
      ),

    define_field: ($) =>
      seq(
        "DEFINE",
        "FIELD",
        field("name", $.identifier),
        ":",
        field("type", $._data_type),
        repeat($.decorator),
        ";",
      ),

    define_role: ($) =>
      seq(
        "DEFINE",
        "ROLE",
        field("name", $.identifier),
        "ALLOWS",
        "[",
        commaSep($.identifier),
        "]",
        ";",
      ),

    define_struct: ($) =>
      seq(
        "DEFINE",
        "STRUCT",
        field("name", $.identifier),
        "{",
        commaSep($.identifier),
        "}",
      ),

    define_trait: ($) =>
      seq(
        "DEFINE",
        "TRAIT",
        field("name", $.identifier),
        "{",
        commaSep($.identifier),
        "}",
      ),

    define_node: ($) =>
      seq(
        "DEFINE",
        optional("ABSTRACT"),
        "NODE",
        field("name", $.identifier),
        optional($.extends_clause),
        $.schema_body,
      ),

    define_edge: ($) =>
      seq(
        "DEFINE",
        optional("ABSTRACT"),
        "EDGE",
        field("name", $.identifier),
        optional($.extends_clause),
        $.schema_body,
      ),

    extends_clause: ($) => seq("EXTENDS", "[", commaSep($.identifier), "]"),

    schema_body: ($) =>
      seq("{", commaSep(choice($.identifier, $.role_definition)), "}"),

    role_definition: ($) =>
      seq(
        field("name", $.identifier),
        ":",
        field("role_type", $.identifier),
        field("cardinality", choice("(ONE)", "(MANY)")),
        repeat($.decorator),
      ),

    define_index: ($) =>
      seq(
        "DEFINE",
        "INDEX",
        field("name", $.identifier),
        "ON",
        field("type", $.identifier),
        "(",
        commaSep($.identifier),
        ")",
        ";",
      ),

    // ==========================================
    // 2. Migration & System
    // ==========================================

    migration_statement: ($) =>
      choice($.validate_migration, $.migrate, $.alter),

    validate_migration: ($) =>
      seq(
        "VALIDATE",
        "MIGRATION",
        $.identifier,
        "TO",
        $.identifier,
        optional($.map_clause),
        optional($.defaults_clause),
      ),

    migrate: ($) =>
      seq(
        "MIGRATE",
        $.identifier,
        "TO",
        $.identifier,
        optional($.map_clause),
        optional($.defaults_clause),
      ),

    alter: ($) =>
      seq(
        "ALTER",
        choice("NODE", "EDGE"),
        $.identifier,
        "{",
        commaSep(
          choice(
            seq("ADD", $.identifier),
            seq("DROP", $.identifier),
            seq("RENAME", $.identifier, "TO", $.identifier),
          ),
        ),
        "}",
      ),

    map_clause: ($) => seq("MAP", "{", commaSep($.map_entry), "}"),
    map_entry: ($) =>
      choice(
        seq($.identifier, ":", $.identifier),
        seq("DROP", "[", commaSep($.identifier), "]"),
      ),

    defaults_clause: ($) =>
      seq("DEFAULTS", "{", commaSep(seq($.identifier, ":", $._literal)), "}"),

    system_statement: ($) =>
      choice(
        seq(
          "SHOW",
          choice("NODE TYPES", "EDGE TYPES", "FIELDS", "ROLES", "SCHEMA"),
        ),
        "EXPLAIN",
        "ANALYZE",
      ),

    batch_statement: ($) =>
      seq(
        "BATCH",
        "{",
        repeat($._statement),
        "}",
        $.return_clause,
        ";"
      ),

    begin_transaction: ($) =>
      seq(
        "BEGIN",
        optional(seq("ISOLATION", "LEVEL", $.isolation_level)),
        optional("ON ERROR CONTINUE"),
        ";"
      ),

    isolation_level: ($) => choice("READ UNCOMMITTED", "READ COMMITTED", "REPEATABLE READ", "SERIALIZABLE"),

    // ==========================================
    // 3. Query / Manipulation (DML)
    // ==========================================

    // FIX: Moved prec.right to wrap the ENTIRE sequence.
    // This tells the parser: "If you can keep consuming clauses into this statement, DO IT."
    manipulation_statement: ($) =>
      prec.right(seq(repeat1($._clause), optional(";"))),

    _clause: ($) =>
      choice(
        $.import_clause,
        $.match_clause,
        $.match_path_clause,
        $.optional_match_clause,
        $.create_node_clause,
        $.create_edge_clause,
        $.merge_clause,
        $.set_clause,
        $.delete_clause,
        $.detach_delete_clause,
        $.remove_clause,
        $.with_clause,
        $.where_clause,
        $.return_clause,
        $.order_by_clause,
        $.limit_clause,
        $.skip_clause,
        $.group_by_clause,
        $.union_clause,
        $.unwind_clause,
      ),

    import_clause: ($) => seq("IMPORT", $.string_literal, "AS", $.identifier),

    match_clause: ($) =>
      seq(
        "MATCH",
        $.pattern,
        optional("CROSS_TYPE"),
        optional($.use_index_hint),
      ),

    match_path_clause: ($) =>
      seq(
        "MATCH",
        "PATH",
        field("path_var", $.identifier),
        "=",
        $.pattern,
        optional($._weight_clause),
      ),

    _weight_clause: ($) =>
      seq(
        "WEIGHT",
        "BY",
        field("weight_field", $.identifier),
        optional(seq("USING", choice("SUM", "MAX", "MIN", "AVG"))),
      ),

    optional_match_clause: ($) => seq("OPTIONAL", "MATCH", $.pattern),

    create_node_clause: ($) =>
      seq(
        "CREATE", "NODE",
        field("variable", $.identifier),
        ":",
        field("type", $.identifier),
        $.map_literal,
        ";"
      ),

    create_edge_clause: ($) =>
      seq(
        "CREATE", "EDGE",
        field("variable", $.identifier),
        ":",
        field("type", $.identifier),
        "{",
        commaSep(choice($.property_assignment, $.role_assignment)),
        "}",
        ";"
      ),

    merge_clause: ($) =>
      seq(
        "MERGE",
        "(",
        field("variable", $.identifier),
        ":",
        field("type", $.identifier),
        "{",
        commaSep(choice($.property_assignment, $.role_assignment)),
        "}",
        ")",
        repeat($.on_action)
      ),

    on_action: ($) =>
      seq(
        "ON",
        choice("CREATE", "MATCH"),
        "SET",
        commaSep1($.assignment_expression),
      ),

    set_clause: ($) =>
      seq(
        "SET",
        commaSep1(
          choice($.assignment_expression, $.atomic_append, $.atomic_remove),
        ),
      ),

    remove_clause: ($) => seq("REMOVE", commaSep1($.identifier)),

    delete_clause: ($) => seq("DELETE", commaSep1($.identifier)),
    detach_delete_clause: ($) =>
      seq("DETACH", "DELETE", commaSep1($.identifier)),

    with_clause: ($) =>
      prec.right(seq("WITH", commaSep1($._projection_element), optional($.where_clause))),

    where_clause: ($) => seq("WHERE", $._expression),

    group_by_clause: ($) => seq("GROUP", "BY", commaSep1($._expression)),

    order_by_clause: ($) =>
      seq(
        "ORDER",
        "BY",
        commaSep1(seq($._expression, optional(choice("ASC", "DESC")))),
      ),

    limit_clause: ($) => seq("LIMIT", $._expression),
    skip_clause: ($) => seq("SKIP", $._expression),

    return_clause: ($) =>
      seq("RETURN", optional("DISTINCT"), commaSep1($._projection_element)),

    union_clause: ($) => choice("UNION", seq("UNION", "ALL")),
    unwind_clause: ($) => seq("UNWIND", $._expression, "AS", $.identifier),

    use_index_hint: ($) => seq("USE", "INDEX", $.identifier),

    // ==========================================
    // 4. Patterns & Expressions
    // ==========================================

    pattern: ($) => commaSep1($.path_pattern),

    path_pattern: ($) =>
      seq(
        $.node_pattern,
        repeat(
          seq($.edge_pattern, $.node_pattern),
        ),
      ),

    node_pattern: ($) =>
      seq(
        "(",
        optional(field("variable", $.identifier)),
        optional(seq(":", field("type", $.identifier))),
        optional(field("properties", $.map_literal)),
        ")",
      ),

    edge_pattern: ($) =>
      seq(
        choice("-", "<-", "-"),
        "[",
        optional(field("variable", $.identifier)),
        optional(seq(":", field("type", $.identifier))),
        optional("*"),
        optional(field("properties", $.map_literal)),
        optional($._weight_clause),
        "]",
        choice("-", "->", "-"),
      ),

    hyper_edge_pattern: ($) => $.edge_pattern,

    _expression: ($) =>
      choice(
        $.identifier,
        $.variable,
        $._literal,
        $.function_call,
        $.property_access,
        $.binary_expression,
        $.unary_expression,
        $.case_expression,
        $.match_expression,
        $.subquery_expression,
        $.window_function,
        seq("(", $._expression, ")"),
      ),

    binary_expression: ($) =>
      choice(
        prec.left(5, seq($._expression, choice("+", "-"), $._expression)),
        prec.left(6, seq($._expression, choice("*", "/", "%"), $._expression)),
        prec.left(
          4,
          seq($._expression, choice("<", ">", "<=", ">="), $._expression),
        ),
        prec.left(
          3,
          seq(
            $._expression,
            choice("==", "=", "!=", "IS", "LIKE", "ILIKE", "MATCHES", "IMATCHES"),
            $._expression,
          ),
        ),
        prec.left(2, seq($._expression, "&&", $._expression)),
        prec.left(1, seq($._expression, "||", $._expression)),
        prec.right(seq($._expression, choice("IN", "IS NULL", "IS NOT NULL"))),
      ),

    unary_expression: ($) =>
      prec(10, choice(seq("!", $._expression), seq("-", $._expression))),

    property_assignment: ($) => seq($.identifier, ":", $._expression),

    role_assignment: ($) => seq($.identifier, "->", $._expression),

    assignment_expression: ($) => seq($.property_access, "=", $._expression),

    atomic_append: ($) => seq($.property_access, "+=", $._expression),
    atomic_remove: ($) => seq($.property_access, "-=", $._expression),

    property_access: ($) =>
      seq(
        field("object", $.identifier),
        repeat1(seq(".", field("property", $.identifier))),
      ),

    function_call: ($) =>
      seq(
        field("name", $.identifier),
        "(",
        commaSep(choice($._expression, "*")),
        ")",
      ),

    window_function: ($) =>
      seq(
        $.function_call,
        "OVER",
        "(",
        optional(seq("PARTITION", "BY", commaSep1($._expression))),
        optional(seq("ORDER", "BY", commaSep1(seq($._expression, optional(choice("ASC", "DESC")))))),
        ")",
      ),

    match_expression: ($) =>
      seq(
        "MATCH",
        $._expression,
        "{",
        commaSep1(seq($._expression, "=>", $._expression)),
        "}",
      ),

    case_expression: ($) =>
      seq(
        "CASE",
        repeat(seq("WHEN", $._expression, "THEN", $._expression)),
        optional(seq("ELSE", $._expression)),
        "END",
      ),

    subquery_expression: ($) =>
      seq(choice("EXISTS", "IN"), "(", $.manipulation_statement, ")"),

    list_expression: ($) => seq("[", commaSep($._expression), "]"),

    // ==========================================
    // 5. Types & Literals
    // ==========================================

    _data_type: ($) =>
      choice(
        "String",
        "Int",
        "Int32",
        "Float",
        "Bool",
        "Date",
        "UUID",
        "Interval",
        "Time",
        "Decimal",
        "Path",
        seq("Vector", "<", $.integer_literal, ">"),
        seq("List", "<", $._data_type, ">"),
        seq("Enum", "<", $.identifier, ">"),
        seq("Struct", "<", $.identifier, ">"),
      ),

    decorator: ($) =>
      seq("@", $.identifier, optional(seq("(", commaSep1($._expression), ")"))),

    _projection_element: ($) =>
      seq($._expression, optional(seq("AS", $.identifier))),

    _literal: ($) =>
      choice(
        $.string_literal,
        $.integer_literal,
        $.float_literal,
        $.boolean_literal,
        $.null_literal,
        $.map_literal,
        $.list_literal,
      ),

    string_literal: ($) => /"[^"]*"/,
    integer_literal: ($) => /\d+/,
    float_literal: ($) => /\d+\.\d+/,
    boolean_literal: ($) => choice("true", "false"),
    null_literal: ($) => "null",
    variable: ($) => seq("$", $.identifier),

    map_literal: ($) =>
      seq("{", commaSep(seq($.identifier, ":", $._expression)), "}"),

    list_literal: ($) => seq("[", commaSep($._expression), "]"),

    identifier: ($) => /[a-zA-Z_][a-zA-Z0-9_]*/,
    namespace_identifier: ($) => /[a-zA-Z_][a-zA-Z0-9_.]*/,

    comment: ($) =>
      token(
        choice(
          seq("//", /.*/),
          seq("--", /.*/),
          seq("/*", /[^*]*\*+([^/*][^*]*\*+)*/, "/"),
        ),
      ),
  },
});

function commaSep(rule) {
  return optional(commaSep1(rule));
}

function commaSep1(rule) {
  return seq(rule, repeat(seq(",", rule)));
}
