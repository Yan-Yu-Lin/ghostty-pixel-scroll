const std = @import("std");
const Allocator = std.mem.Allocator;
const internal_os = @import("../os/main.zig");

const log = std.log.scoped(.neovim_profile);

/// Configuration profile mode for Neovim GUI sessions.
pub const Mode = enum {
    /// Prefer the user's own ~/.config/nvim if it exists, otherwise fall back
    /// to a Ghostty-managed profile.
    auto,
    /// Always use the user's own Neovim profile (~/.config/nvim).
    user,
    /// Always use the Ghostty-managed profile (~/.config/ghostty/nvim).
    managed,
};

/// Concrete launch mode after resolving `auto`.
pub const ResolvedMode = enum {
    user,
    managed,
};

/// Resolve `auto` mode to either user or managed based on whether a user
/// Neovim config exists.
pub fn resolveMode(mode: Mode) ResolvedMode {
    return switch (mode) {
        .user => .user,
        .managed => .managed,
        .auto => if (userConfigExists()) .user else .managed,
    };
}

/// Return true if ~/.config/nvim exists.
pub fn userConfigExists() bool {
    var home_buf: [std.fs.max_path_bytes]u8 = undefined;
    const home = (internal_os.home(&home_buf) catch return false) orelse return false;

    var home_dir = std.fs.openDirAbsolute(home, .{}) catch return false;
    defer home_dir.close();

    if (home_dir.access(".config/nvim", .{})) |_| {
        return true;
    } else |_| {
        return false;
    }
}

/// Apply environment overrides so Neovim uses Ghostty-managed paths:
/// - config: ~/.config/ghostty/nvim
/// - data:   ~/.local/share/ghostty/nvim
/// - state:  ~/.local/state/ghostty/nvim
/// - cache:  ~/.cache/ghostty/nvim
pub fn applyManagedEnv(alloc: Allocator, env: *std.process.EnvMap) !void {
    var home_buf: [std.fs.max_path_bytes]u8 = undefined;
    const home = internal_os.home(&home_buf) catch |err| {
        log.warn("failed to determine home directory for managed nvim env: {}", .{err});
        return;
    } orelse {
        log.warn("home directory unavailable for managed nvim env", .{});
        return;
    };

    const xdg_config_home = try std.fmt.allocPrint(alloc, "{s}/.config/ghostty", .{home});
    defer alloc.free(xdg_config_home);

    const xdg_data_home = try std.fmt.allocPrint(alloc, "{s}/.local/share/ghostty", .{home});
    defer alloc.free(xdg_data_home);

    const xdg_state_home = try std.fmt.allocPrint(alloc, "{s}/.local/state/ghostty", .{home});
    defer alloc.free(xdg_state_home);

    const xdg_cache_home = try std.fmt.allocPrint(alloc, "{s}/.cache/ghostty", .{home});
    defer alloc.free(xdg_cache_home);

    try env.put("XDG_CONFIG_HOME", xdg_config_home);
    try env.put("XDG_DATA_HOME", xdg_data_home);
    try env.put("XDG_STATE_HOME", xdg_state_home);
    try env.put("XDG_CACHE_HOME", xdg_cache_home);

    // NVIM_APPNAME = nvim so stdpaths resolve under the XDG roots above.
    // Example: config => ~/.config/ghostty/nvim
    try env.put("NVIM_APPNAME", "nvim");
}

/// Get the absolute init.lua path for Ghostty-managed profile.
/// Caller owns returned memory.
pub fn managedInitPath(alloc: Allocator) !?[]const u8 {
    var home_buf: [std.fs.max_path_bytes]u8 = undefined;
    const home = (internal_os.home(&home_buf) catch return null) orelse return null;
    return try std.fmt.allocPrint(alloc, "{s}/.config/ghostty/nvim/init.lua", .{home});
}

/// Ensure the managed profile exists at ~/.config/ghostty/nvim by seeding it
/// from bundled resources (share/ghostty/nvim) on first launch.
pub fn ensureManagedProfileSeeded(alloc: Allocator, resources_dir: ?[]const u8) !void {
    const base = resources_dir orelse {
        log.warn("resources dir unavailable; cannot seed managed nvim profile", .{});
        return;
    };

    const source_dir = try std.fmt.allocPrint(alloc, "{s}/nvim", .{base});
    defer alloc.free(source_dir);

    if (std.fs.accessAbsolute(source_dir, .{})) |_| {} else |_| {
        log.warn("bundled nvim profile not found at: {s}", .{source_dir});
        return;
    }

    var home_buf: [std.fs.max_path_bytes]u8 = undefined;
    const home = internal_os.home(&home_buf) catch |err| {
        log.warn("failed to determine home directory for managed nvim seed: {}", .{err});
        return;
    } orelse {
        log.warn("home directory unavailable for managed nvim seed", .{});
        return;
    };

    const target_dir = try std.fmt.allocPrint(alloc, "{s}/.config/ghostty/nvim", .{home});
    defer alloc.free(target_dir);

    // Ensure parent path exists.
    var home_dir = try std.fs.openDirAbsolute(home, .{});
    defer home_dir.close();
    try home_dir.makePath(".config/ghostty/nvim");

    // First launch: copy full bundled profile.
    if (std.fs.accessAbsolute(target_dir, .{})) |_| {
        // Existing managed profile: only backfill missing bundled files so users
        // keep their edits while still getting newly added managed defaults.
        try copyMissingFilesRecursive(alloc, source_dir, target_dir);
        return;
    } else |_| {}

    try copyDirRecursive(alloc, source_dir, target_dir);
    log.info("seeded managed nvim profile at: {s}", .{target_dir});
}

fn copyDirRecursive(alloc: Allocator, source_path: []const u8, target_path: []const u8) !void {
    var source = try std.fs.openDirAbsolute(source_path, .{ .iterate = true });
    defer source.close();

    var target = try std.fs.openDirAbsolute(target_path, .{});
    defer target.close();

    var walker = try source.walk(alloc);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        switch (entry.kind) {
            .directory => {
                try target.makePath(entry.path);
            },
            .file => {
                if (std.fs.path.dirname(entry.path)) |parent| {
                    try target.makePath(parent);
                }
                try source.copyFile(entry.path, target, entry.path, .{});
            },
            else => {},
        }
    }
}

fn copyMissingFilesRecursive(alloc: Allocator, source_path: []const u8, target_path: []const u8) !void {
    var source = try std.fs.openDirAbsolute(source_path, .{ .iterate = true });
    defer source.close();

    var target = try std.fs.openDirAbsolute(target_path, .{});
    defer target.close();

    // Migration guard:
    // If users already have the managed extras inside lua/plugins/init.lua
    // from older builds, skip backfilling ghostty_extras.lua to avoid duplicate specs.
    const target_plugins_init = try std.fmt.allocPrint(alloc, "{s}/lua/plugins/init.lua", .{target_path});
    defer alloc.free(target_plugins_init);
    const init_has_managed_extras = fileContainsAny(
        alloc,
        target_plugins_init,
        &.{
            "folke/noice.nvim",
            "parkers0405/hlchunk.nvim",
            "esmuellert/codediff.nvim",
        },
    ) catch false;

    var walker = try source.walk(alloc);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        switch (entry.kind) {
            .directory => {
                try target.makePath(entry.path);
            },
            .file => {
                const is_managed_extras = std.mem.eql(u8, entry.path, "lua/plugins/ghostty_extras.lua");
                if (init_has_managed_extras and is_managed_extras) {
                    continue;
                }

                if (std.fs.path.dirname(entry.path)) |parent| {
                    try target.makePath(parent);
                }

                // Keep managed defaults current for all users:
                // refresh ghostty_extras.lua every launch unless we're preserving
                // legacy profiles that already inlined those extras in init.lua.
                if (is_managed_extras) {
                    target.deleteFile(entry.path) catch |err| switch (err) {
                        error.FileNotFound => {},
                        else => return err,
                    };
                    try source.copyFile(entry.path, target, entry.path, .{});
                    continue;
                }

                if (target.access(entry.path, .{})) |_| {
                    continue;
                } else |_| {}

                try source.copyFile(entry.path, target, entry.path, .{});
            },
            else => {},
        }
    }
}

fn fileContainsAny(alloc: Allocator, file_path: []const u8, needles: []const []const u8) !bool {
    var file = std.fs.openFileAbsolute(file_path, .{}) catch |err| switch (err) {
        error.FileNotFound => return false,
        else => return err,
    };
    defer file.close();

    const data = try file.readToEndAlloc(alloc, 1024 * 1024);
    defer alloc.free(data);

    for (needles) |needle| {
        if (std.mem.indexOf(u8, data, needle) != null) return true;
    }
    return false;
}
