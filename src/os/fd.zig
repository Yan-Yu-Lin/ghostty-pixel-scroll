const std = @import("std");
const global = @import("../global.zig");

/// Close a POSIX descriptor through the active Zig I/O backend.
pub inline fn close(handle: std.posix.fd_t) void {
    const file: std.Io.File = .{
        .handle = handle,
        .flags = .{ .nonblocking = false },
    };
    file.close(global.io());
}

/// Enable O_NONBLOCK while preserving the descriptor's existing flags.
pub inline fn setNonblocking(handle: std.posix.fd_t) void {
    const flags = std.c.fcntl(handle, std.c.F.GETFL, @as(c_int, 0));
    if (flags < 0) return;
    const nonblocking: c_int = @bitCast(std.c.O{ .NONBLOCK = true });
    _ = std.c.fcntl(handle, std.c.F.SETFL, flags | nonblocking);
}

/// Write the complete payload through the active Zig I/O backend.
pub inline fn writeAll(handle: std.posix.fd_t, data: []const u8) !void {
    const file: std.Io.File = .{
        .handle = handle,
        .flags = .{ .nonblocking = true },
    };
    try file.writeStreamingAll(global.io(), data);
}
