const std = @import("std");
const Allocator = std.mem.Allocator;
const internal_os = @import("../os/main.zig");

const log = std.log.scoped(.neovim_profile);

const EmbeddedProfileFile = struct {
    path: []const u8,
    data: []const u8,
};

const embedded_profile_files = [_]EmbeddedProfileFile{
    .{ .path = "init.lua", .data = @embedFile("../neovim_profile/init.lua") },
    .{ .path = "lua/bootstrap.lua", .data = @embedFile("../neovim_profile/lua/bootstrap.lua") },
    .{ .path = "lua/chadrc.lua", .data = @embedFile("../neovim_profile/lua/chadrc.lua") },
    .{ .path = "lua/configs/lazy.lua", .data = @embedFile("../neovim_profile/lua/configs/lazy.lua") },
    .{ .path = "lua/configs/lsp_defaults.lua", .data = @embedFile("../neovim_profile/lua/configs/lsp_defaults.lua") },
    .{ .path = "lua/mappings.lua", .data = @embedFile("../neovim_profile/lua/mappings.lua") },
    .{ .path = "lua/options.lua", .data = @embedFile("../neovim_profile/lua/options.lua") },
    .{ .path = "lua/plugins/ghostty_extras.lua", .data = @embedFile("../neovim_profile/lua/plugins/ghostty_extras.lua") },
    .{ .path = "lua/plugins/init.lua", .data = @embedFile("../neovim_profile/lua/plugins/init.lua") },
    .{ .path = "plugin/ghostty_bootstrap.lua", .data = @embedFile("../neovim_profile/plugin/ghostty_bootstrap.lua") },
};

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
    var source_dir: ?[]const u8 = null;
    defer if (source_dir) |dir| alloc.free(dir);
    var use_embedded_seed = true;

    if (resources_dir) |base| {
        source_dir = try std.fmt.allocPrint(alloc, "{s}/nvim", .{base});
        if (std.fs.accessAbsolute(source_dir.?, .{})) |_| {
            use_embedded_seed = false;
        } else |_| {
            log.warn("bundled nvim profile not found at: {s}; falling back to embedded profile", .{source_dir.?});
        }
    } else {
        log.warn("resources dir unavailable; falling back to embedded managed nvim profile", .{});
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
    // Suppress NvChad one-time Blink integration announcement popup in
    // managed profiles by pre-creating its marker directory.
    try home_dir.makePath(".local/share/ghostty/nvim/nvnotify1");

    if (use_embedded_seed) {
        // Seed from embedded fallback so managed mode still works when runtime
        // resources aren't discoverable (for example some dev/local launches).
        try seedEmbeddedProfile(target_dir);
        try migrateManagedOptionsShowbreak(alloc, target_dir);
        try migrateManagedOptionsStatuslineBaseline(alloc, target_dir);
        try migrateManagedMappingsCleanup(alloc, target_dir);
        try migrateManagedMappingsDiffview(alloc, target_dir);
        try migrateManagedInitResilience(alloc, target_dir);
        try migrateManagedOptionsNvchadGuard(alloc, target_dir);
        log.info("seeded managed nvim profile from embedded fallback at: {s}", .{target_dir});
        return;
    }

    // First launch: copy full bundled profile.
    if (std.fs.accessAbsolute(target_dir, .{})) |_| {
        // Existing managed profile: only backfill missing bundled files so users
        // keep their edits while still getting newly added managed defaults.
        try copyMissingFilesRecursive(alloc, source_dir.?, target_dir);
        try migrateManagedOptionsShowbreak(alloc, target_dir);
        try migrateManagedOptionsStatuslineBaseline(alloc, target_dir);
        try migrateManagedMappingsCleanup(alloc, target_dir);
        try migrateManagedMappingsDiffview(alloc, target_dir);
        try migrateManagedInitResilience(alloc, target_dir);
        try migrateManagedOptionsNvchadGuard(alloc, target_dir);
        return;
    } else |_| {}

    try copyDirRecursive(alloc, source_dir.?, target_dir);
    try migrateManagedOptionsShowbreak(alloc, target_dir);
    try migrateManagedOptionsStatuslineBaseline(alloc, target_dir);
    try migrateManagedMappingsCleanup(alloc, target_dir);
    try migrateManagedMappingsDiffview(alloc, target_dir);
    try migrateManagedInitResilience(alloc, target_dir);
    try migrateManagedOptionsNvchadGuard(alloc, target_dir);
    log.info("seeded managed nvim profile at: {s}", .{target_dir});
}

fn shouldAlwaysRefreshManagedFile(path: []const u8) bool {
    return std.mem.eql(u8, path, "lua/plugins/ghostty_extras.lua") or
        std.mem.eql(u8, path, "lua/bootstrap.lua") or
        std.mem.eql(u8, path, "plugin/ghostty_bootstrap.lua");
}

fn seedEmbeddedProfile(target_path: []const u8) !void {
    var target = try std.fs.openDirAbsolute(target_path, .{});
    defer target.close();

    for (embedded_profile_files) |file| {
        if (std.fs.path.dirname(file.path)) |parent| {
            try target.makePath(parent);
        }

        if (shouldAlwaysRefreshManagedFile(file.path)) {
            target.deleteFile(file.path) catch |err| switch (err) {
                error.FileNotFound => {},
                else => return err,
            };
        } else {
            if (target.access(file.path, .{})) |_| {
                continue;
            } else |_| {}
        }

        try target.writeFile(.{
            .sub_path = file.path,
            .data = file.data,
        });
    }
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
    var init_has_managed_extras = fileContainsAny(
        alloc,
        target_plugins_init,
        &.{
            "folke/noice.nvim",
            "parkers0405/hlchunk.nvim",
            "sindrets/diffview.nvim",
            "esmuellert/codediff.nvim",
        },
    ) catch false;

    // Migrate legacy managed profiles that inlined Ghostty defaults directly
    // inside lua/plugins/init.lua. Replace that file with the current minimal
    // managed template so lua/plugins/ghostty_extras.lua can be synced normally.
    if (init_has_managed_extras and (isLegacyManagedPluginsInit(alloc, target_plugins_init) catch false)) {
        try source.copyFile("lua/plugins/init.lua", target, "lua/plugins/init.lua", .{});
        init_has_managed_extras = false;
    }

    var walker = try source.walk(alloc);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        switch (entry.kind) {
            .directory => {
                try target.makePath(entry.path);
            },
            .file => {
                const is_managed_extras = std.mem.eql(u8, entry.path, "lua/plugins/ghostty_extras.lua");
                const is_managed_bootstrap = std.mem.eql(u8, entry.path, "lua/bootstrap.lua");
                const is_managed_bootstrap_plugin = std.mem.eql(u8, entry.path, "plugin/ghostty_bootstrap.lua");
                if (init_has_managed_extras and is_managed_extras) {
                    continue;
                }

                if (std.fs.path.dirname(entry.path)) |parent| {
                    try target.makePath(parent);
                }

                // Keep managed defaults current for all users:
                // refresh ghostty_extras.lua every launch unless we're preserving
                // legacy profiles that already inlined those extras in init.lua.
                if (is_managed_extras or is_managed_bootstrap or is_managed_bootstrap_plugin) {
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

fn migrateManagedOptionsShowbreak(alloc: Allocator, target_path: []const u8) !void {
    const options_path = try std.fmt.allocPrint(alloc, "{s}/lua/options.lua", .{target_path});
    defer alloc.free(options_path);

    var file = std.fs.openFileAbsolute(options_path, .{}) catch |err| switch (err) {
        error.FileNotFound => return,
        else => return err,
    };
    defer file.close();

    const data = try file.readToEndAlloc(alloc, 1024 * 1024);
    defer alloc.free(data);

    const old_showbreak = "o.showbreak = \"> \"";
    if (std.mem.indexOf(u8, data, old_showbreak) == null) return;

    const updated = try std.mem.replaceOwned(
        u8,
        alloc,
        data,
        old_showbreak,
        "o.showbreak = \"\xE2\x86\xAA \"",
    );
    defer alloc.free(updated);

    var target_dir = try std.fs.openDirAbsolute(target_path, .{});
    defer target_dir.close();
    try target_dir.writeFile(.{
        .sub_path = "lua/options.lua",
        .data = updated,
    });

    log.info("migrated managed nvim options showbreak marker", .{});
}

fn migrateManagedOptionsStatuslineBaseline(alloc: Allocator, target_path: []const u8) !void {
    const options_path = try std.fmt.allocPrint(alloc, "{s}/lua/options.lua", .{target_path});
    defer alloc.free(options_path);

    var file = std.fs.openFileAbsolute(options_path, .{}) catch |err| switch (err) {
        error.FileNotFound => return,
        else => return err,
    };
    defer file.close();

    const data = try file.readToEndAlloc(alloc, 1024 * 1024);
    defer alloc.free(data);

    const has_laststatus = std.mem.indexOf(u8, data, "o.laststatus") != null or
        std.mem.indexOf(u8, data, "vim.o.laststatus") != null;
    const has_showmode = std.mem.indexOf(u8, data, "o.showmode") != null or
        std.mem.indexOf(u8, data, "vim.o.showmode") != null;
    const has_ruler = std.mem.indexOf(u8, data, "o.ruler") != null or
        std.mem.indexOf(u8, data, "vim.o.ruler") != null;

    if (has_laststatus and has_showmode and has_ruler) return;

    var updated = std.ArrayList(u8).empty;
    defer updated.deinit(alloc);
    try updated.appendSlice(alloc, data);

    if (updated.items.len > 0 and updated.items[updated.items.len - 1] != '\n') {
        try updated.append(alloc, '\n');
    }

    try updated.appendSlice(alloc, "\n-- Keep a real statusline visible in nvim-gui on first attach.\n");
    if (!has_laststatus) try updated.appendSlice(alloc, "o.laststatus = 3\n");
    if (!has_showmode) try updated.appendSlice(alloc, "o.showmode = false\n");
    if (!has_ruler) try updated.appendSlice(alloc, "o.ruler = false\n");

    var target_dir = try std.fs.openDirAbsolute(target_path, .{});
    defer target_dir.close();
    try target_dir.writeFile(.{
        .sub_path = "lua/options.lua",
        .data = updated.items,
    });

    log.info("migrated managed nvim options statusline baseline", .{});
}

fn migrateManagedMappingsCleanup(alloc: Allocator, target_path: []const u8) !void {
    const mappings_path = try std.fmt.allocPrint(alloc, "{s}/lua/mappings.lua", .{target_path});
    defer alloc.free(mappings_path);

    var file = std.fs.openFileAbsolute(mappings_path, .{}) catch |err| switch (err) {
        error.FileNotFound => return,
        else => return err,
    };
    defer file.close();

    const data = try file.readToEndAlloc(alloc, 1024 * 1024);
    defer alloc.free(data);

    const block_start = std.mem.indexOf(u8, data, "local telescope_split_preview = {") orelse return;
    const end_words = std.mem.indexOfPos(u8, data, block_start, "end, { desc = \"Find words (split preview)\" })");
    const end_quickfix = std.mem.indexOfPos(u8, data, block_start, "end, { desc = \"Quickfix (split preview)\" })");

    const end_marker = marker: {
        if (end_words) |i| break :marker i;
        if (end_quickfix) |i| break :marker i;
        return;
    };

    const end_line = std.mem.indexOfScalarPos(u8, data, end_marker, '\n') orelse data.len;
    var cut_end: usize = if (end_line < data.len) end_line + 1 else data.len;
    if (cut_end < data.len and data[cut_end] == '\n') cut_end += 1;

    const updated = try std.mem.concat(alloc, u8, &.{ data[0..block_start], data[cut_end..] });
    defer alloc.free(updated);

    var target_dir = try std.fs.openDirAbsolute(target_path, .{});
    defer target_dir.close();
    try target_dir.writeFile(.{
        .sub_path = "lua/mappings.lua",
        .data = updated,
    });

    log.info("cleaned managed nvim telescope keymap overrides", .{});
}

fn migrateManagedMappingsDiffview(alloc: Allocator, target_path: []const u8) !void {
    const mappings_path = try std.fmt.allocPrint(alloc, "{s}/lua/mappings.lua", .{target_path});
    defer alloc.free(mappings_path);

    var file = std.fs.openFileAbsolute(mappings_path, .{}) catch |err| switch (err) {
        error.FileNotFound => return,
        else => return err,
    };
    defer file.close();

    const data = try file.readToEndAlloc(alloc, 1024 * 1024);
    defer alloc.free(data);

    if (std.mem.indexOf(u8, data, "<cmd>CodeDiff<CR>") == null) return;

    const updated_cmd = try std.mem.replaceOwned(
        u8,
        alloc,
        data,
        "<cmd>CodeDiff<CR>",
        "<cmd>DiffviewOpen<CR>",
    );
    defer alloc.free(updated_cmd);

    const updated_desc = try std.mem.replaceOwned(
        u8,
        alloc,
        updated_cmd,
        "Open CodeDiff",
        "Open Diffview",
    );
    defer alloc.free(updated_desc);

    var target_dir = try std.fs.openDirAbsolute(target_path, .{});
    defer target_dir.close();
    try target_dir.writeFile(.{
        .sub_path = "lua/mappings.lua",
        .data = updated_desc,
    });

    log.info("migrated managed nvim mappings to Diffview", .{});
}

fn migrateManagedInitResilience(alloc: Allocator, target_path: []const u8) !void {
    const init_path = try std.fmt.allocPrint(alloc, "{s}/init.lua", .{target_path});
    defer alloc.free(init_path);

    var file = std.fs.openFileAbsolute(init_path, .{}) catch |err| switch (err) {
        error.FileNotFound => return,
        else => return err,
    };
    defer file.close();

    const data = try file.readToEndAlloc(alloc, 1024 * 1024);
    defer alloc.free(data);

    var updated = data;
    var changed = false;

    if (std.mem.indexOf(u8, updated, "require(\"options\")") != null) {
        const replaced = try std.mem.replaceOwned(
            u8,
            alloc,
            updated,
            "require(\"options\")",
            "pcall(require, \"options\")",
        );
        if (changed) alloc.free(updated);
        updated = replaced;
        changed = true;
    }

    if (std.mem.indexOf(u8, updated, "require(\"nvchad.autocmds\")") != null) {
        const replaced = try std.mem.replaceOwned(
            u8,
            alloc,
            updated,
            "require(\"nvchad.autocmds\")",
            "pcall(require, \"nvchad.autocmds\")",
        );
        if (changed) alloc.free(updated);
        updated = replaced;
        changed = true;
    }

    if (std.mem.indexOf(u8, updated, "require(\"bootstrap\").setup()") != null) {
        const replaced = try std.mem.replaceOwned(
            u8,
            alloc,
            updated,
            "require(\"bootstrap\").setup()",
            "pcall(function()\n\trequire(\"bootstrap\").setup()\nend)",
        );
        if (changed) alloc.free(updated);
        updated = replaced;
        changed = true;
    }

    if (std.mem.indexOf(u8, updated, "\trequire(\"mappings\")") != null) {
        const replaced = try std.mem.replaceOwned(
            u8,
            alloc,
            updated,
            "\trequire(\"mappings\")",
            "\tpcall(require, \"mappings\")",
        );
        if (changed) alloc.free(updated);
        updated = replaced;
        changed = true;
    }

    if (std.mem.indexOf(u8, updated, "table.insert(specs, { import = \"nvchad.blink.lazyspec\" })") != null) {
        const replaced = try std.mem.replaceOwned(
            u8,
            alloc,
            updated,
            "table.insert(specs, { import = \"nvchad.blink.lazyspec\" })",
            "local nvchad_blink_spec = lazy_root .. \"/NvChad/lua/nvchad/blink/lazyspec.lua\"\n\t\tif exists(nvchad_blink_spec) then\n\t\t\ttable.insert(specs, { import = \"nvchad.blink.lazyspec\" })\n\t\tend",
        );
        if (changed) alloc.free(updated);
        updated = replaced;
        changed = true;
    }

    if (std.mem.indexOf(u8, updated, "table.insert(specs, {\n\t\t\t\"williamboman/mason.nvim\",") == null) {
        const legacy_fallback =
            "else\n\t\t-- Fallback: avoid hard import errors when offline or before first install.\n\t\ttable.insert(specs, {\n\t\t\t\"NvChad/NvChad\",\n\t\t\tlazy = true,\n\t\t\tbranch = \"v2.5\",\n\t\t})\n\tend";
        if (std.mem.indexOf(u8, updated, legacy_fallback) != null) {
            const replaced = try std.mem.replaceOwned(
                u8,
                alloc,
                updated,
                legacy_fallback,
                "else\n\t\t-- Fallback: avoid hard import errors when offline or before first install.\n\t\ttable.insert(specs, {\n\t\t\t\"NvChad/NvChad\",\n\t\t\tlazy = true,\n\t\t\tbranch = \"v2.5\",\n\t\t})\n\t\t-- Minimal bootstrap plugins for first launch before NvChad imports resolve.\n\t\ttable.insert(specs, {\n\t\t\t\"williamboman/mason.nvim\",\n\t\t\tlazy = true,\n\t\t})\n\t\ttable.insert(specs, {\n\t\t\t\"nvim-treesitter/nvim-treesitter\",\n\t\t\tlazy = true,\n\t\t})\n\tend",
            );
            if (changed) alloc.free(updated);
            updated = replaced;
            changed = true;
        }
    }

    if (!changed) return;
    defer alloc.free(updated);

    var target_dir = try std.fs.openDirAbsolute(target_path, .{});
    defer target_dir.close();
    try target_dir.writeFile(.{
        .sub_path = "init.lua",
        .data = updated,
    });

    log.info("migrated managed nvim init resilience guards", .{});
}

fn migrateManagedOptionsNvchadGuard(alloc: Allocator, target_path: []const u8) !void {
    const options_path = try std.fmt.allocPrint(alloc, "{s}/lua/options.lua", .{target_path});
    defer alloc.free(options_path);

    var file = std.fs.openFileAbsolute(options_path, .{}) catch |err| switch (err) {
        error.FileNotFound => return,
        else => return err,
    };
    defer file.close();

    const data = try file.readToEndAlloc(alloc, 1024 * 1024);
    defer alloc.free(data);

    if (std.mem.indexOf(u8, data, "require(\"nvchad.options\")") == null) return;

    const updated = try std.mem.replaceOwned(
        u8,
        alloc,
        data,
        "require(\"nvchad.options\")",
        "pcall(require, \"nvchad.options\")",
    );
    defer alloc.free(updated);

    var target_dir = try std.fs.openDirAbsolute(target_path, .{});
    defer target_dir.close();
    try target_dir.writeFile(.{
        .sub_path = "lua/options.lua",
        .data = updated,
    });

    log.info("migrated managed nvim options nvchad guard", .{});
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

fn isLegacyManagedPluginsInit(alloc: Allocator, file_path: []const u8) !bool {
    var file = std.fs.openFileAbsolute(file_path, .{}) catch |err| switch (err) {
        error.FileNotFound => return false,
        else => return err,
    };
    defer file.close();

    const data = try file.readToEndAlloc(alloc, 1024 * 1024);
    defer alloc.free(data);

    // New template marker means no migration needed.
    if (std.mem.indexOf(u8, data, "Managed Ghostty defaults are shipped in") != null) {
        return false;
    }

    const has_noice = std.mem.indexOf(u8, data, "folke/noice.nvim") != null;
    const has_hlchunk = std.mem.indexOf(u8, data, "parkers0405/hlchunk.nvim") != null;
    const has_diff_plugin =
        std.mem.indexOf(u8, data, "sindrets/diffview.nvim") != null or
        std.mem.indexOf(u8, data, "esmuellert/codediff.nvim") != null;

    return has_noice and has_hlchunk and has_diff_plugin;
}
