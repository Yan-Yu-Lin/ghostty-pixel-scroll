const std = @import("std");
const global = @import("global.zig");

/// Monotonic timestamp with the pre-Zig-0.16 Instant interface used by the
/// animation and input paths in this fork.
pub const Instant = struct {
    timestamp: std.Io.Timestamp,

    pub inline fn now() Instant {
        return .{ .timestamp = .now(global.io(), .awake) };
    }

    pub inline fn order(self: Instant, other: Instant) std.math.Order {
        return std.math.order(self.timestamp.nanoseconds, other.timestamp.nanoseconds);
    }

    pub inline fn since(self: Instant, earlier: Instant) u64 {
        return @intCast(@max(0, earlier.timestamp.durationTo(self.timestamp).nanoseconds));
    }
};
