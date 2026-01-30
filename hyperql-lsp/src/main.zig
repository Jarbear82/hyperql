const std = @import("std");
const lsp = @import("lsp");

pub fn main() !void {
    var gpa_state = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa_state.deinit();
    const allocator = gpa_state.allocator();

    var read_buffer: [4096]u8 = undefined;
    
    const stdin = std.fs.File{ .handle = std.posix.STDIN_FILENO };
    const stdout = std.fs.File{ .handle = std.posix.STDOUT_FILENO };

    var transport_storage = lsp.Transport.Stdio.init(
        &read_buffer,
        stdin,
        stdout,
    );
    
    var handler = Handler{ .allocator = allocator };
    try lsp.basic_server.run(allocator, &transport_storage.transport, &handler, null);
}

const Handler = struct {
    allocator: std.mem.Allocator,
    documents: std.StringHashMapUnmanaged([]const u8) = .{},

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
                .definitionProvider = .{ .bool = true },
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

    pub fn @"textDocument/didOpen"(
        self: *Handler, 
        arena: std.mem.Allocator, 
        params: lsp.types.DidOpenTextDocumentParams
    ) !void {
        _ = arena;
        const uri = try self.allocator.dupe(u8, params.textDocument.uri);
        const text = try self.allocator.dupe(u8, params.textDocument.text);
        try self.documents.put(self.allocator, uri, text);
    }

    pub fn @"textDocument/didChange"(
        self: *Handler, 
        arena: std.mem.Allocator, 
        params: lsp.types.DidChangeTextDocumentParams
    ) !void {
        _ = arena;
        const uri = params.textDocument.uri;
        if (self.documents.getPtr(uri)) |doc_ptr| {
            // We assume Full sync, so contentChanges[0] has the full text
            if (params.contentChanges.len > 0) {
                const change = params.contentChanges[0];
                switch (change) {
                    .literal_1 => |full_text| {
                        self.allocator.free(doc_ptr.*);
                        doc_ptr.* = try self.allocator.dupe(u8, full_text.text);
                    },
                    else => {},
                }
            }
        }
    }

    pub fn @"textDocument/didClose"(
        self: *Handler, 
        arena: std.mem.Allocator, 
        params: lsp.types.DidCloseTextDocumentParams
    ) !void {
        _ = arena;
        if (self.documents.fetchRemove(params.textDocument.uri)) |kv| {
            self.allocator.free(kv.key);
            self.allocator.free(kv.value);
        }
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

    pub fn @"textDocument/definition"(
        self: *Handler,
        arena: std.mem.Allocator,
        params: lsp.types.DefinitionParams,
    ) !lsp.ResultType("textDocument/definition") {
        _ = arena;
        
        const uri = params.textDocument.uri;
        const doc_text = self.documents.get(uri) orelse return null;
        
        // 1. Get word at position
        const word = getWordAtPosition(doc_text, params.position) orelse return null;
        
        // 2. Scan for definition (DEFINE ... Word)
        // We scan the same document for now.
        if (findDefinition(doc_text, word)) |location| {
            // We need to return Location with URI
            return .{
                .Definition = .{
                    .Location = .{
                        .uri = uri, // Same document
                        .range = location.range,
                    }
                }
            };
        }
        
        return null;
    }

    fn getWordAtPosition(text: []const u8, pos: lsp.types.Position) ?[]const u8 {
        var line_it = std.mem.splitScalar(u8, text, '\n');
        var line_idx: u32 = 0;
        while (line_it.next()) |line| : (line_idx += 1) {
            if (line_idx == pos.line) {
                if (pos.character >= line.len) return null;
                
                const is_word_char = struct {
                    fn check(c: u8) bool {
                        return std.ascii.isAlphanumeric(c) or c == '_' or c == '@';
                    }
                }.check;

                var start: usize = pos.character;
                while (start > 0 and is_word_char(line[start-1])) : (start -= 1) {}
                
                var end: usize = pos.character;
                while (end < line.len and is_word_char(line[end])) : (end += 1) {}
                
                if (start < end) {
                    return line[start..end];
                }
                return null;
            }
        }
        return null;
    }

    fn findDefinition(text: []const u8, word: []const u8) ?lsp.types.Location {
        var line_it = std.mem.splitScalar(u8, text, '\n');
        var line_idx: u32 = 0;
        
        while (line_it.next()) |line| : (line_idx += 1) {
            // Check if line contains "DEFINE" and the word
            if (std.mem.indexOf(u8, line, "DEFINE") != null) {
                if (std.mem.indexOf(u8, line, word)) |idx| {
                    // Very naive check: just return this line if found
                    return lsp.types.Location{
                        .uri = "", // Placeholder
                        .range = .{
                            .start = .{ .line = line_idx, .character = @intCast(idx) },
                            .end = .{ .line = line_idx, .character = @intCast(idx + word.len) },
                        },
                    };
                }
            }
        }
        return null;
    }
};