const std = @import("std");

/// Borrow an environment variable from libc without allocating.
pub inline fn get(name: [*:0]const u8) ?[:0]const u8 {
    const value = std.c.getenv(name) orelse return null;
    return std.mem.span(value);
}
