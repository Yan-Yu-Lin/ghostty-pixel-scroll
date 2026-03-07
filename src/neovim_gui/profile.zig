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
///
/// Only NVIM_APPNAME is set (to "ghostty/nvim") so that Neovim's stdpath()
/// resolves under the standard XDG roots (e.g. config => ~/.config/ghostty/nvim).
/// Global XDG variables are intentionally *not* overridden — this keeps tools
/// spawned from within Neovim (git, opencode, terminal shells, etc.) using
/// the user's normal system configuration.
pub fn applyManagedEnv(_: Allocator, env: *std.process.EnvMap) !void {
    // NVIM_APPNAME supports path separators.  Setting it to "ghostty/nvim"
    // makes Neovim resolve stdpath('config') to $XDG_CONFIG_HOME/ghostty/nvim
    // (i.e. ~/.config/ghostty/nvim) without altering XDG_CONFIG_HOME itself.
    try env.put("NVIM_APPNAME", "ghostty/nvim");
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
    // Suppress NvChad one-time Blink integration announcement popup in
    // managed profiles by pre-creating its marker directory.
    try home_dir.makePath(".local/share/ghostty/nvim/nvnotify1");

    // First launch: copy full bundled profile.
    if (std.fs.accessAbsolute(target_dir, .{})) |_| {
        // Existing managed profile: only backfill missing bundled files so users
        // keep their edits while still getting newly added managed defaults.
        try copyMissingFilesRecursive(alloc, source_dir, target_dir);
        try migrateManagedChadrcBufferline(alloc, target_dir);
        try migrateManagedOptionsShowbreak(alloc, target_dir);
        try migrateManagedOptionsVirtualedit(alloc, target_dir);
        try migrateManagedOptionsTerminalWrap(alloc, target_dir);
        try migrateManagedMappingsBufferline(alloc, target_dir);
        try migrateManagedMappingsLazyTelescope(alloc, target_dir);
        try migrateManagedMappingsCleanup(alloc, target_dir);
        try migrateManagedMappingsDiffview(alloc, target_dir);
        try migrateManagedFilePermissionsWritable(alloc, target_dir);
        return;
    } else |_| {}

    try copyDirRecursive(alloc, source_dir, target_dir);
    try migrateManagedChadrcBufferline(alloc, target_dir);
    try migrateManagedOptionsShowbreak(alloc, target_dir);
    try migrateManagedOptionsVirtualedit(alloc, target_dir);
    try migrateManagedOptionsTerminalWrap(alloc, target_dir);
    try migrateManagedMappingsBufferline(alloc, target_dir);
    try migrateManagedMappingsLazyTelescope(alloc, target_dir);
    try migrateManagedMappingsCleanup(alloc, target_dir);
    try migrateManagedMappingsDiffview(alloc, target_dir);
    try migrateManagedFilePermissionsWritable(alloc, target_dir);
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

    target.deleteFile("lua/configs/bufferline.lua") catch |err| switch (err) {
        error.FileNotFound => {},
        else => return err,
    };

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
                const is_managed_tabufline_config = std.mem.eql(u8, entry.path, "lua/configs/tabufline.lua");
                const is_managed_treesitter_config = std.mem.eql(u8, entry.path, "lua/configs/treesitter.lua");
                if (init_has_managed_extras and is_managed_extras) {
                    continue;
                }

                if (std.fs.path.dirname(entry.path)) |parent| {
                    try target.makePath(parent);
                }

                // Keep managed defaults current for all users:
                // refresh ghostty_extras.lua every launch unless we're preserving
                // legacy profiles that already inlined those extras in init.lua.
                if (is_managed_extras or
                    is_managed_bootstrap or
                    is_managed_bootstrap_plugin or
                    is_managed_tabufline_config or
                    is_managed_treesitter_config)
                {
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

fn migrateManagedFilePermissionsWritable(alloc: Allocator, target_path: []const u8) !void {
    if (@import("builtin").os.tag == .windows) return;

    var target = try std.fs.openDirAbsolute(target_path, .{ .iterate = true });
    defer target.close();

    var walker = try target.walk(alloc);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;

        var file = target.openFile(entry.path, .{}) catch |err| switch (err) {
            error.FileNotFound => continue,
            else => return err,
        };
        defer file.close();

        const stat = try file.stat();
        const desired_mode = stat.mode | 0o200;
        if (desired_mode != stat.mode) {
            try file.chmod(desired_mode);
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

fn migrateManagedOptionsVirtualedit(alloc: Allocator, target_path: []const u8) !void {
    const options_path = try std.fmt.allocPrint(alloc, "{s}/lua/options.lua", .{target_path});
    defer alloc.free(options_path);

    var file = std.fs.openFileAbsolute(options_path, .{}) catch |err| switch (err) {
        error.FileNotFound => return,
        else => return err,
    };
    defer file.close();

    const data = try file.readToEndAlloc(alloc, 1024 * 1024);
    defer alloc.free(data);

    const old_virtualedit = "o.virtualedit = \"all\"";
    if (std.mem.indexOf(u8, data, old_virtualedit) == null) return;

    const updated = try std.mem.replaceOwned(
        u8,
        alloc,
        data,
        old_virtualedit,
        "o.virtualedit = \"block\"",
    );
    defer alloc.free(updated);

    var target_dir = try std.fs.openDirAbsolute(target_path, .{});
    defer target_dir.close();
    try target_dir.writeFile(.{
        .sub_path = "lua/options.lua",
        .data = updated,
    });

    log.info("migrated managed nvim options virtualedit mode", .{});
}

fn migrateManagedOptionsTerminalWrap(alloc: Allocator, target_path: []const u8) !void {
    const options_path = try std.fmt.allocPrint(alloc, "{s}/lua/options.lua", .{target_path});
    defer alloc.free(options_path);

    var file = std.fs.openFileAbsolute(options_path, .{}) catch |err| switch (err) {
        error.FileNotFound => return,
        else => return err,
    };
    defer file.close();

    const data = try file.readToEndAlloc(alloc, 1024 * 1024);
    defer alloc.free(data);

    const marker = "ghostty_terminal_wrap";
    if (std.mem.indexOf(u8, data, marker) != null) return;

    const snippet =
        \\
        \\-- Keep terminal-buffer TUIs (like opencode/crush) in fixed-grid mode.
        \\-- Global wrap/linebreak settings are great for prose buffers, but they can
        \\-- visually corrupt full-screen terminal UIs by wrapping control-drawn lines.
        \\local terminal_wrap_group = vim.api.nvim_create_augroup("ghostty_terminal_wrap", { clear = true })
        \\vim.api.nvim_create_autocmd({ "TermOpen", "BufEnter", "WinEnter" }, {
        \\    group = terminal_wrap_group,
        \\    callback = function(args)
        \\        if not vim.api.nvim_buf_is_valid(args.buf) then
        \\            return
        \\        end
        \\        if vim.bo[args.buf].buftype ~= "terminal" then
        \\            return
        \\        end
        \\
        \\        vim.wo.wrap = false
        \\        vim.wo.linebreak = false
        \\        vim.wo.breakindent = false
        \\        vim.wo.showbreak = ""
        \\    end,
        \\})
        \\
    ;

    const updated = try std.mem.concat(alloc, u8, &.{ data, snippet });
    defer alloc.free(updated);

    var target_dir = try std.fs.openDirAbsolute(target_path, .{});
    defer target_dir.close();
    try target_dir.writeFile(.{
        .sub_path = "lua/options.lua",
        .data = updated,
    });

    log.info("migrated managed nvim terminal wrap settings", .{});
}

fn migrateManagedChadrcBufferline(alloc: Allocator, target_path: []const u8) !void {
    const chadrc_path = try std.fmt.allocPrint(alloc, "{s}/lua/chadrc.lua", .{target_path});
    defer alloc.free(chadrc_path);

    var file = std.fs.openFileAbsolute(chadrc_path, .{}) catch |err| switch (err) {
        error.FileNotFound => return,
        else => return err,
    };
    defer file.close();

    const data = try file.readToEndAlloc(alloc, 1024 * 1024);
    defer alloc.free(data);

    var updated = try alloc.dupe(u8, data);
    defer alloc.free(updated);

    const old_block = "\ttabufline = {\n\t\tenabled = true,\n\t},\n";
    if (std.mem.indexOf(u8, updated, old_block)) |_| {
        const replaced = try std.mem.replaceOwned(
            u8,
            alloc,
            updated,
            old_block,
            "\ttabufline = {\n\t\tenabled = false,\n\t},\n",
        );
        alloc.free(updated);
        updated = replaced;
    }

    const bufferline_integration = "\tintegrations = { \"bufferline\" },\n";
    if (std.mem.indexOf(u8, updated, bufferline_integration)) |_| {
        const replaced = try std.mem.replaceOwned(
            u8,
            alloc,
            updated,
            bufferline_integration,
            "",
        );
        alloc.free(updated);
        updated = replaced;
    }

    const nixd_pkg = "\t\t\"nixd\",\n";
    if (std.mem.indexOf(u8, updated, nixd_pkg)) |_| {
        const replaced = try std.mem.replaceOwned(
            u8,
            alloc,
            updated,
            nixd_pkg,
            "",
        );
        alloc.free(updated);
        updated = replaced;
    }

    var target_dir = try std.fs.openDirAbsolute(target_path, .{});
    defer target_dir.close();
    try target_dir.writeFile(.{
        .sub_path = "lua/chadrc.lua",
        .data = updated,
    });

    log.info("migrated managed nvim chadrc tabufline toggle", .{});
}

fn migrateManagedMappingsBufferline(alloc: Allocator, target_path: []const u8) !void {
    const mappings_path = try std.fmt.allocPrint(alloc, "{s}/lua/mappings.lua", .{target_path});
    defer alloc.free(mappings_path);

    var file = std.fs.openFileAbsolute(mappings_path, .{}) catch |err| switch (err) {
        error.FileNotFound => return,
        else => return err,
    };
    defer file.close();

    const data = try file.readToEndAlloc(alloc, 1024 * 1024);
    defer alloc.free(data);

    const old_block =
        "map(\"n\", \"<Tab>\", function()\n" ++ "\trequire(\"nvchad.tabufline\").next()\n" ++ "end, { desc = \"Next buffer\" })\n\n" ++ "map(\"n\", \"<C-Tab>\", function()\n" ++ "\trequire(\"nvchad.tabufline\").prev()\n" ++ "end, { desc = \"Previous buffer\" })\n\n" ++ "map(\"n\", \"<leader>x\", function()\n" ++ "\trequire(\"nvchad.tabufline\").close_buffer()\n" ++ "end, { desc = \"Close buffer\" })\n";

    if (std.mem.indexOf(u8, data, old_block) == null) return;

    const updated = try std.mem.replaceOwned(
        u8,
        alloc,
        data,
        old_block,
        "map(\"n\", \"<Tab>\", function()\n" ++ "\trequire(\"configs.bufferline\").cycle_next()\n" ++ "end, { desc = \"Next buffer\" })\n\n" ++ "map(\"n\", \"<C-Tab>\", function()\n" ++ "\trequire(\"configs.bufferline\").cycle_prev()\n" ++ "end, { desc = \"Previous buffer\" })\n\n" ++ "map(\"n\", \"<leader>x\", function()\n" ++ "\trequire(\"configs.bufferline\").close_current()\n" ++ "end, { desc = \"Close buffer\" })\n\n" ++ "map(\"n\", \"<leader>bp\", \"<cmd>BufferLinePick<CR>\", { desc = \"Pick buffer\" })\n",
    );
    defer alloc.free(updated);

    var target_dir = try std.fs.openDirAbsolute(target_path, .{});
    defer target_dir.close();
    try target_dir.writeFile(.{
        .sub_path = "lua/mappings.lua",
        .data = updated,
    });

    log.info("migrated managed nvim bufferline mappings", .{});
}

fn migrateManagedMappingsLazyTelescope(alloc: Allocator, target_path: []const u8) !void {
    const mappings_path = try std.fmt.allocPrint(alloc, "{s}/lua/mappings.lua", .{target_path});
    defer alloc.free(mappings_path);

    var file = std.fs.openFileAbsolute(mappings_path, .{}) catch |err| switch (err) {
        error.FileNotFound => return,
        else => return err,
    };
    defer file.close();

    const data = try file.readToEndAlloc(alloc, 1024 * 1024);
    defer alloc.free(data);

    const old_block =
        "local builtin = require(\"telescope.builtin\")\n" ++
        "map(\"n\", \"<leader>fs\", builtin.lsp_document_symbols, { desc = \"Search document symbols\" })\n" ++
        "map(\"n\", \"<leader>fS\", builtin.lsp_dynamic_workspace_symbols, { desc = \"Search workspace symbols\" })\n" ++
        "map(\"n\", \"<leader>fr\", builtin.lsp_references, { desc = \"Find references\" })\n" ++
        "map(\"n\", \"<leader>fd\", builtin.lsp_definitions, { desc = \"Find definitions\" })\n" ++
        "map(\"n\", \"<leader>fi\", builtin.lsp_implementations, { desc = \"Find implementations\" })\n";

    if (std.mem.indexOf(u8, data, old_block) == null) return;

    const updated = try std.mem.replaceOwned(
        u8,
        alloc,
        data,
        old_block,
        "local function telescope_builtin(name)\n" ++
            "\treturn function()\n" ++
            "\t\trequire(\"telescope.builtin\")[name]()\n" ++
            "\tend\n" ++
            "end\n\n" ++
            "map(\"n\", \"<leader>fs\", telescope_builtin(\"lsp_document_symbols\"), { desc = \"Search document symbols\" })\n" ++
            "map(\"n\", \"<leader>fS\", telescope_builtin(\"lsp_dynamic_workspace_symbols\"), { desc = \"Search workspace symbols\" })\n" ++
            "map(\"n\", \"<leader>fr\", telescope_builtin(\"lsp_references\"), { desc = \"Find references\" })\n" ++
            "map(\"n\", \"<leader>fd\", telescope_builtin(\"lsp_definitions\"), { desc = \"Find definitions\" })\n" ++
            "map(\"n\", \"<leader>fi\", telescope_builtin(\"lsp_implementations\"), { desc = \"Find implementations\" })\n",
    );
    defer alloc.free(updated);

    var target_dir = try std.fs.openDirAbsolute(target_path, .{});
    defer target_dir.close();
    try target_dir.writeFile(.{
        .sub_path = "lua/mappings.lua",
        .data = updated,
    });

    log.info("migrated managed nvim telescope mappings to lazy requires", .{});
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
