module.exports = grammar({
  name: "hyperql",

  extras: ($) => [$.comment, /\s/],

  word: ($) => $.identifier,

  rules: {
    source_file: ($) => repeat($._statement),

    _statement: ($) =>
      seq(
        choice(
          $.definition_statement,
          $.manipulation_statement,
          $.migration_statement,
          $.system_statement,
          $.batch_statement,
          $.transaction_statement,
        ),
        ";",
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
      ),

    define_enum: ($) =>
      seq(
        "DEFINE",
        "ENUM",
        field("name", $.identifier),
        "{",
        commaSepTrailing(field("value", $.identifier)),
        "}",
      ),

    define_field: ($) =>
      seq(
        "DEFINE",
        "FIELD",
        field("name", $.identifier),
        ":",
        field("type", $._data_type),
        optional("?"),
        repeat($.decorator),
      ),

    define_role: ($) =>
      seq(
        "DEFINE",
        "ROLE",
        field("name", $.identifier),
        "ALLOWS",
        choice(
          // List of types, optionally followed by constraints
          seq(
            "[",
            commaSep1($.identifier),
            "]",
            optional($.constraint_block),
          ),
          // Single type with colon (New Syntax)
          seq($.identifier, ":", $.constraint_block),
          // Single type, optionally followed by constraints (Old Syntax fallback)
          seq($.identifier, optional($.constraint_block)),
        ),
      ),

    define_struct: ($) =>
      seq(
        "DEFINE",
        "STRUCT",
        field("name", $.identifier),
        "{",
        commaSepTrailing(field("field", $.identifier)),
        "}",
      ),

    define_trait: ($) =>
      seq(
        "DEFINE",
        "TRAIT",
        field("name", $.identifier),
        "{",
        commaSepTrailing(field("field", $.identifier)),
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
        optional($.constraint_block),
      ),

    define_edge: ($) =>
      seq(
        "DEFINE",
        optional("ABSTRACT"),
        "EDGE",
        field("name", $.identifier),
        optional($.extends_clause),
        $.schema_body,
        optional($.constraint_block),
      ),

    extends_clause: ($) => seq("EXTENDS", "[", commaSep1($.identifier), "]"),

    schema_body: ($) =>
      seq(
        "{",
        commaSepTrailing(choice($.role_definition, $.field_definition, $.identifier, $.comment)),
        "}",
      ),

    field_definition: ($) =>
      seq(
        field("name", $.identifier),
        optional("?"),
        ":",
        field("type", $._data_type),
        repeat($.decorator),
      ),

    role_definition: ($) =>
      choice(
        seq(
          field("name", $.identifier),
          optional("?"),
          ":",
          optional(field("direction", choice("<-", "->", "<->"))),
          field("role_type", $.identifier),
          field("cardinality", choice("(ONE)", "(MANY)")),
          repeat($.decorator),
        ),
        seq(
          field("name", $.identifier),
          optional("?"),
          field("direction", choice("<-", "->", "<->")),
          field("cardinality", choice("(ONE)", "(MANY)")),
          repeat($.decorator),
        ),
      ),

    constraint_block: ($) =>
      seq(
        "{",
        "constraints",
        ":",
        choice(
          seq("[", commaSepTrailing($._expression), "]"),
          seq("{", commaSepTrailing($.named_constraint), "}"),
        ),
        "}",
      ),

    named_constraint: ($) => seq($.identifier, ":", $._expression),

    define_index: ($) =>
      seq(
        "DEFINE",
        "INDEX",
        field("name", $.identifier),
        "ON",
        field("type", $.identifier),
        "(",
        commaSep1($.identifier),
        ")",
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
        commaSepTrailing(
          choice(
            seq("ADD", $.identifier),
            seq("DROP", $.identifier),
            seq("RENAME", $.identifier, "TO", $.identifier),
            seq("ADD", "CONSTRAINT", $.identifier, ":", $._expression),
          ),
        ),
        "}",
      ),

    map_clause: ($) => seq("MAP", "{", commaSepTrailing($.map_entry), "}"),
    map_entry: ($) =>
      choice(
        seq($.identifier, ":", $.identifier),
        seq("DROP", "[", commaSep1($.identifier), "]"),
      ),

    defaults_clause: ($) =>
      seq("DEFAULTS", "{", commaSepTrailing(seq($.identifier, ":", $._literal)), "}"),

    system_statement: ($) =>
      choice(
        seq(
          "SHOW",
          choice(
            seq("NODE", "TYPES"),
            seq("EDGE", "TYPES"),
            "FIELDS",
            "ROLES",
            "SCHEMA",
            seq("TRANSACTION", "LOG", "SIZE"),
          ),
        ),
        seq(
          choice("EXPLAIN", "ANALYZE"),
          optional(choice("VERBOSE", "JSON")),
          optional($.manipulation_statement),
        ),
      ),

    batch_statement: ($) =>
      seq("BATCH", "{", repeat($._statement), "}", optional($.return_clause)),

    transaction_statement: ($) =>
      choice(
        seq(
          "BEGIN",
          optional(seq("ISOLATION", "LEVEL", $.isolation_level)),
          optional("ON ERROR CONTINUE"),
        ),
        "COMMIT",
        "ROLLBACK",
        seq("SET", "ISOLATION", "LEVEL", $.isolation_level),
      ),

    isolation_level: ($) =>
      choice(
        "READ UNCOMMITTED",
        "READ COMMITTED",
        "REPEATABLE READ",
        "SERIALIZABLE",
        "READ_UNCOMMITTED",
        "READ_COMMITTED",
        "REPEATABLE_READ",
      ),

    // ==========================================
    // 3. Query / Manipulation (DML)
    // ==========================================

    manipulation_statement: ($) => repeat1($._clause),

    _clause: ($) =>
      choice(
        $.import_clause,
        $.match_clause,
        $.match_path_clause,
        $.optional_match_clause,
        $.create_node_clause,
        $.create_edge_clause,
        $.merge_clause,
        $.merge_object_clause,
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

    merge_object_clause: ($) =>
      seq(
        "MERGE",
        "OBJECT",
        field("variable", $.identifier),
        "WITH",
        field("map", $._expression),
      ),

    match_clause: ($) =>
      seq(
        "MATCH",
        $.pattern,
        optional("CROSS_TYPE"),
        optional($.use_index_hint),
      ),

    match_path_clause: ($) =>
      seq("MATCH", "PATH", field("path_var", $.identifier), "=", $.pattern),

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
        "CREATE",
        "NODE",
        field("variable", $.identifier),
        ":",
        field("type", $.dotted_identifier),
        $.map_literal,
      ),

    create_edge_clause: ($) =>
      seq(
        "CREATE",
        "EDGE",
        field("variable", $.identifier),
        ":",
        field("type", $.dotted_identifier),
        "{",
        commaSepTrailing(choice($.property_assignment, $.role_binding)),
        "}",
      ),

    merge_clause: ($) =>
      seq(
        "MERGE",
        "(",
        field("variable", $.identifier),
        ":",
        field("type", $.dotted_identifier),
        "{",
        commaSepTrailing(choice($.property_assignment, $.role_binding)),
        "}",
        ")",
        repeat($.on_action),
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
          choice(
            $.assignment_expression,
            $.atomic_append,
            $.atomic_remove,
            seq($.identifier, "+=", $.map_literal),
          ),
        ),
      ),

    remove_clause: ($) => seq("REMOVE", commaSep1($.property_access)),

    delete_clause: ($) => seq("DELETE", commaSep1($.identifier)),
    detach_delete_clause: ($) =>
      seq("DETACH", "DELETE", commaSep1($.identifier)),

    with_clause: ($) =>
      prec.right(
        seq("WITH", commaSep1($._projection_element), optional($.where_clause)),
      ),

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
      seq($.node_pattern, repeat(seq($.edge_pattern, $.node_pattern))),

    node_pattern: ($) =>
      seq(
        "(",
        optional(field("variable", $.identifier)),
        optional(seq(":", field("type", $.dotted_identifier))),
        optional(
          seq(
            "{",
            commaSepTrailing(choice($.property_assignment, $.role_binding)),
            "}",
          ),
        ),
        ")",
      ),

    edge_pattern: ($) =>
      seq(
        choice("-", "<-"),
        "[",
        optional(field("variable", $.identifier)),
        optional(seq(":", field("type", $.dotted_identifier))),
        optional(seq("*", optional($.range_literal))),
        optional(
          seq(
            "{",
            commaSepTrailing(choice($.property_assignment, $.role_binding)),
            "}",
          ),
        ),
        optional($._weight_clause),
        "]",
        choice("-", "->"),
      ),

    range_literal: ($) =>
      choice(
        $.integer_literal,
        seq($.integer_literal, "..", optional($.integer_literal)),
        seq("..", $.integer_literal),
      ),

    _expression: ($) =>
      choice(
        $.identifier,
        $.inferred_identifier,
        $.variable,
        $._literal,
        $.function_call,
        $.list_predicate,
        $.property_access,
        $.binary_expression,
        $.unary_expression,
        $.postfix_expression,
        $.case_expression,
        $.if_expression,
        $.match_expression,
        $.subquery_expression,
        $.window_function,
        seq("(", $._expression, ")"),
      ),

    inferred_identifier: ($) => seq(".", $.identifier),

    list_predicate: ($) =>
      seq(
        choice("ALL", "ANY", "NONE", "SINGLE"),
        "(",
        field("variable", $.identifier),
        "IN",
        field("list", $._expression),
        optional(seq("WHERE", field("condition", $._expression))),
        ")",
      ),

    binary_expression: ($) =>
      choice(
        prec.left(12, seq($._expression, choice("+", "-"), $._expression)),
        prec.left(14, seq($._expression, choice("*", "/", "%"), $._expression)),
        prec.left(
          10,
          seq($._expression, choice("<", ">", "<=", ">="), $._expression),
        ),
        prec.left(15, seq($._expression, "??", $._expression)),
        prec.left(
          8,
          seq(
            $._expression,
            choice(
              "==",
              "=",
              "!=",
              "IS",
              "LIKE",
              "ILIKE",
              "MATCHES",
              "IMATCHES",
            ),
            $._expression,
          ),
        ),
        prec.left(6, seq($._expression, choice("&&", "AND"), $._expression)),
        prec.left(4, seq($._expression, choice("||", "OR"), $._expression)),
        prec.left(7, seq($._expression, "IN", $._expression)),
      ),

    unary_expression: ($) =>
      prec(
        16,
        choice(seq(choice("!", "NOT"), $._expression), seq("-", $._expression)),
      ),

    postfix_expression: ($) =>
      prec(
        8,
        seq(
          $._expression,
          choice(
            seq("IS", "NULL"),
            seq("IS", "NOT", "NULL"),
            "IS NULL",
            "IS NOT NULL",
          ),
        ),
      ),

    property_assignment: ($) =>
      seq(field("name", $.identifier), "=", field("value", $._expression)),

    assignment_expression: ($) => prec(15, seq($.property_access, "=", $._expression)),

    role_binding: ($) => seq(field("name", $.identifier), "=>", field("value", $._expression)),

    atomic_append: ($) => seq($.property_access, "+=", $._expression),
    atomic_remove: ($) => seq($.property_access, "-=", $._expression),

    property_access: ($) =>
      prec.left(
        20,
        seq(
          field("object", $._expression),
          repeat1(seq(choice(".", "?."), field("property", $.identifier))),
        ),
      ),

    function_call: ($) =>
      prec(
        18,
        seq(
          field("name", $.identifier),
          "(",
          commaSepTrailing(choice($._expression, "*")),
          ")",
        ),
      ),

    window_function: ($) =>
      seq(
        $.function_call,
        "OVER",
        "(",
        optional(seq("PARTITION", "BY", commaSep1($._expression))),
        optional(
          seq(
            "ORDER",
            "BY",
            commaSep1(seq($._expression, optional(choice("ASC", "DESC")))),
          )
        ),
        optional($.window_frame),
        ")",
      ),

    window_frame: ($) =>
      seq(
        choice("ROWS", "RANGE"),
        "BETWEEN",
        $.window_frame_bound,
        "AND",
        $.window_frame_bound,
      ),

    window_frame_bound: ($) =>
      choice(
        seq("UNBOUNDED", "PRECEDING"),
        seq("UNBOUNDED", "FOLLOWING"),
        seq("CURRENT", "ROW"),
        seq($._expression, choice("PRECEDING", "FOLLOWING")),
      ),

    match_expression: ($) =>
      seq(
        "MATCH",
        $._expression,
        "{",
        commaSepTrailing(seq($._expression, "=>", $._expression)),
        "}",
      ),

    case_expression: ($) =>
      seq(
        "CASE",
        repeat(seq("WHEN", $._expression, "THEN", $._expression)),
        optional(seq("ELSE", $._expression)),
        "END",
      ),

    if_expression: ($) =>
      seq(
        "IF",
        field("condition", $._expression),
        "THEN",
        field("consequence", $._expression),
        "ELSE",
        field("alternative", $._expression),
        "END",
      ),

    subquery_expression: ($) =>
      seq(choice("EXISTS", "IN", "NOT EXISTS"), "(", $.manipulation_statement, ")"),

    list_expression: ($) => seq("[", commaSepTrailing($._expression), "]"),

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
        "Path",
        seq(
          "Decimal",
          optional(seq("(", $.integer_literal, ",", $.integer_literal, ")")),
        ),
        seq("Vector", "<", $.integer_literal, ">"),
        seq("List", "<", $._data_type, ">"),
        seq("Enum", "<", $.dotted_identifier, ">"),
        seq("Struct", "<", $.dotted_identifier, ">"),
        $.dotted_identifier,
      ),

    decorator: ($) =>
      seq(
        "@",
        $.identifier,
        optional(
          choice(
            seq("(", commaSep1($._expression), ")"),
            seq("(", "TRAVERSE", ")", "{", $.manipulation_statement, "}"),
          )
        ),
      ),

    _projection_element: ($) =>
      seq(
        choice(
          seq($.identifier, "{", commaSepTrailing($.identifier), "}"),
          $._expression,
        ),
        optional(seq("AS", $.identifier)),
      ),

    _literal: ($) =>
      choice(
        $.string_literal,
        $.decimal_literal,
        $.integer_literal,
        $.float_literal,
        $.boolean_literal,
        $.null_literal,
        $.map_literal,
        $.list_literal,
      ),

    string_literal: ($) =>
      seq(
        '"',
        repeat(
          choice(token.immediate(prec(1, /[^\\"\n]+/)), $.escape_sequence),
        ),
        '"',
      ),

    decimal_literal: ($) => /[0-9]+(\.[0-9]+)?d/,

    escape_sequence: ($) =>
      token.immediate(
        seq(
          "\\",
          choice(
            /[^xuU]/,
            /\d{2,3}/,
            /x[0-9a-fA-F]{2,}/,
            /u[0-9a-fA-F]{4}/,
            /U[0-9a-fA-F]{8}/,
          ),
        ),
      ),

    integer_literal: ($) =>
      token(
        choice(
          /[0-9]+(_[0-9]+)*/,
          /0[xX][0-9a-fA-F]+(_[0-9a-fA-F]+)*/,
          /0[bB][01]+(_[01]+)*/,
          /0[oO][0-7]+(_[0-7]+)*/,
        ),
      ),

    float_literal: ($) =>
      token(
        choice(
          /[0-9]+(_[0-9]+)*\.[0-9]+(_[0-9]+)*([eE][+-]?[0-9]+(_[0-9]+)*)?/,
          /[0-9]+(_[0-9]+)*[eE][+-]?[0-9]+(_[0-9]+)*/,
        ),
      ),

    boolean_literal: ($) => choice("true", "false"),
    null_literal: ($) => "null",
    variable: ($) => seq("$", $.identifier),

    map_literal: ($) =>
      seq(
        "{",
        commaSepTrailing(choice($.property_assignment, $.role_binding)),
        "}",
      ),

    list_literal: ($) => seq("[", commaSepTrailing($._expression), "]"),

    identifier: ($) => /[a-zA-Z_][a-zA-Z0-9_]*/,
    namespace_identifier: ($) => /[a-zA-Z_][a-zA-Z0-9_.]*/,
    dotted_identifier: ($) => seq($.identifier, repeat(seq(".", $.identifier))),

    comment: ($) =>
      token(
        choice(
          seq("//", /.*/),
          seq("--", /.*/),
          seq("/*", /[^*]*\*+([^/*][^*]*\*+)*/, "/"),
        ),
      ),
  },

  conflicts: ($) => [
    [$.system_statement, $.manipulation_statement],
    [$._clause, $.manipulation_statement],
    [$._expression, $.property_access],
  ],
});

function commaSep(rule) {
  return optional(commaSep1(rule));
}

function commaSep1(rule) {
  return seq(rule, repeat(seq(",", rule)));
}

function commaSepTrailing(rule) {
  return optional(seq(rule, repeat(seq(",", rule)), optional(",")));
}
