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
};
