const std = @import("std");
const lsp = @import("lsp");

pub fn main() !void {
    var gpa_state = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa_state.deinit();
    const allocator = gpa_state.allocator();

    var read_buffer: [4096]u8 = undefined;
    
    // Manual construction of stdin/stdout files using posix file descriptors
    const stdin = std.fs.File{ .handle = std.posix.STDIN_FILENO };
    const stdout = std.fs.File{ .handle = std.posix.STDOUT_FILENO };

    var transport_storage = lsp.Transport.Stdio.init(
        &read_buffer,
        stdin,
        stdout,
    );
    
    var handler = Handler{};
    // Pass null for the logger
    try lsp.basic_server.run(allocator, &transport_storage.transport, &handler, null);
}

const Handler = struct {
    pub fn initialize(
        self: *Handler,
        arena: std.mem.Allocator,
        params: lsp.types.InitializeParams,
    ) !lsp.types.InitializeResult {
        _ = self;
        _ = arena;
        _ = params;
        
        return lsp.types.InitializeResult{
            .capabilities = .{
                .textDocumentSync = .{
                    .TextDocumentSyncKind = .Full,
                },
                .hoverProvider = .{ .bool = true },
                .completionProvider = .{
                    .triggerCharacters = &[_][]const u8{ "@", "." },
                },
            },
            .serverInfo = .{
                .name = "hyperql-lsp",
                .version = "0.1.0",
            },
        };
    }

    pub fn initialized(
        self: *Handler,
        arena: std.mem.Allocator,
        params: lsp.types.InitializedParams,
    ) void {
        _ = self;
        _ = arena;
        _ = params;
    }

    pub fn onResponse(
        self: *Handler,
        arena: std.mem.Allocator,
        response: lsp.JsonRPCMessage.Response,
    ) void {
        _ = self;
        _ = arena;
        _ = response;
    }

    pub fn @"textDocument/hover"(
        self: *Handler,
        arena: std.mem.Allocator,
        params: lsp.types.HoverParams,
    ) !?lsp.types.Hover {
        _ = self;
        _ = arena;
        _ = params;
        
        return lsp.types.Hover{
            .contents = .{
                .MarkupContent = .{
                    .kind = .markdown,
                    .value = "Hello from HyperQL LSP!",
                },
            },
        };
    }

    pub fn @"textDocument/completion"(
        self: *Handler,
        arena: std.mem.Allocator,
        params: lsp.types.CompletionParams,
    ) !lsp.ResultType("textDocument/completion") {
        _ = self;
        _ = params;
        
        var items = std.ArrayListUnmanaged(lsp.types.CompletionItem){};
        
        // Keywords with documentation
        const keywords = [_]struct { label: []const u8, doc: []const u8 }{
            .{ .label = "DEFINE", .doc = "Defines a schema element (NODE, EDGE, etc.)" },
            .{ .label = "NAMESPACE", .doc = "Declares the namespace for the current schema file." },
            .{ .label = "ENUM", .doc = "Defines a closed set of named constants." },
            .{ .label = "FIELD", .doc = "Defines a global, reusable Property Type configuration." },
            .{ .label = "ROLE", .doc = "Defines a global role interface with optional constraints." },
            .{ .label = "STRUCT", .doc = "Defines a value object container." },
            .{ .label = "TRAIT", .doc = "Defines a composable set of properties (Interface/Mixin)." },
            .{ .label = "NODE", .doc = "Defines a strict Node Type with optional entity-level constraints." },
            .{ .label = "EDGE", .doc = "Defines a strict Hyperedge with optional relationship-level constraints." },
            .{ .label = "INDEX", .doc = "Creates a composite index on multiple fields." },
            .{ .label = "ABSTRACT", .doc = "Defines a Type that can be extended but never instantiated directly." },
            .{ .label = "EXTENDS", .doc = "Implements field composition via global field definitions." },
            .{ .label = "STRICT_MODE", .doc = "Controls inline property definition allowance." },
            .{ .label = "MATCH", .doc = "Pattern matching clause." },
            .{ .label = "RETURN", .doc = "Returns values from the query." },
            .{ .label = "CREATE", .doc = "Creates nodes or edges." },
            .{ .label = "DELETE", .doc = "Deletes nodes or edges." },
            .{ .label = "SET", .doc = "Updates properties." },
            .{ .label = "WHERE", .doc = "Filters results." },
            .{ .label = "WITH", .doc = "Chains query parts." },
            .{ .label = "MIGRATE", .doc = "Type conversion operation. Destructive by design." },
            .{ .label = "VALIDATE", .doc = "Non-destructive preview of migration." },
            .{ .label = "ALTER", .doc = "Modifies an existing schema definition." },
            .{ .label = "BATCH", .doc = "Atomic block that executes all statements." },
            .{ .label = "BEGIN", .doc = "Starts a transaction." },
            .{ .label = "COMMIT", .doc = "Commits the current transaction." },
            .{ .label = "ROLLBACK", .doc = "Rolls back the current transaction." },
            .{ .label = "ISOLATION", .doc = "Used in SET ISOLATION LEVEL." },
            .{ .label = "LEVEL", .doc = "Used in SET ISOLATION LEVEL." },
            .{ .label = "ON", .doc = "Used in ON ERROR CONTINUE." },
            .{ .label = "ERROR", .doc = "Used in ON ERROR CONTINUE." },
            .{ .label = "CONTINUE", .doc = "Used in ON ERROR CONTINUE." },
            .{ .label = "GROUP", .doc = "Groups results." },
            .{ .label = "ORDER", .doc = "Sorts results." },
            .{ .label = "BY", .doc = "Used in GROUP BY / ORDER BY." },
            .{ .label = "LIMIT", .doc = "Limits result count." },
            .{ .label = "SKIP", .doc = "Skips results." },
            .{ .label = "DISTINCT", .doc = "Removes duplicate values." },
            .{ .label = "UNION", .doc = "Combines query results." },
            .{ .label = "ALL", .doc = "Used in UNION ALL." },
            .{ .label = "USE", .doc = "Used in USE INDEX." },
            .{ .label = "SHOW", .doc = "Introspection command." },
            .{ .label = "EXPLAIN", .doc = "Shows query execution plan." },
            .{ .label = "ANALYZE", .doc = "Executes query and shows statistics." },
            .{ .label = "IMPORT", .doc = "Imports a namespace." },
            .{ .label = "OPTIONAL", .doc = "Used in OPTIONAL MATCH." },
            .{ .label = "EXISTS", .doc = "Boolean operator checking for results." },
            .{ .label = "IN", .doc = "Boolean operator checking membership." },
            .{ .label = "LIKE", .doc = "Wildcard pattern matching." },
            .{ .label = "ILIKE", .doc = "Case-insensitive wildcard pattern matching." },
            .{ .label = "MATCHES", .doc = "Regex pattern matching." },
            .{ .label = "IMATCHES", .doc = "Case-insensitive regex pattern matching." },
        };
        
        for (keywords) |kw| {
            try items.append(arena, .{
                .label = kw.label,
                .kind = .Keyword,
                .documentation = .{ .string = kw.doc },
            });
        }
        
        // Types
        const types = [_][]const u8{
            "String", "Int", "Int32", "Float", "Bool", "Date", "UUID", 
            "Decimal", "Interval", "Time", "Vector", "List", "Enum", "Struct", "PATH"
        };

        for (types) |t| {
             try items.append(arena, .{
                .label = t,
                .kind = .Class,
            });
        }

        // Decorators
        const decorators = [_][]const u8{
            "@computed", "@deferred", "@volatile", "@materialized", "@display",
            "@unique", "@required", "@readonly", "@ordered", "@unordered", "@index"
        };
        
        for (decorators) |d| {
             try items.append(arena, .{
                .label = d,
                .kind = .Property,
            });
        }

        // Functions
        const functions = [_][]const u8{
            "TO_STRING", "TO_INT", "TO_FLOAT", "TO_DECIMAL", "UPPER", "LOWER", 
            "LEN", "TRIM", "SUBSTR", "CONCAT", "CONTAINS", "STARTS_WITH", 
            "ENDS_WITH", "ABS", "ROUND", "FLOOR", "CEIL", "MIN", "MAX", 
            "NOW", "YEAR", "MONTH", "DAY", "DATE", "TIME", "INTERVAL", 
            "COALESCE", "NULLIF", "UUID", "LIST_INDEX", "LIST_SLICE", "IF"
        };
        
        for (functions) |f| {
            try items.append(arena, .{
                .label = f,
                .kind = .Function,
            });
        }

        return .{
            .CompletionList = .{
                .isIncomplete = false,
                .items = items.items,
            },
        };
    }
};
