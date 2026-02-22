local M = {}

local uv = vim.uv or vim.loop
local done_marker = vim.fn.stdpath("state") .. "/ghostty/bootstrap-v3.done"
local welcome_marker = vim.fn.stdpath("state") .. "/ghostty/welcome-v1.done"
local setup_done = vim.g.ghostty_bootstrap_setup_done
local quiet_state = nil
local bootstrap_start_scheduled = false
local startup_overlay_filetypes = {
	lazy = true,
	mason = true,
}

local default_mason_packages = {
	"lua-language-server",
	"bash-language-server",
	"json-lsp",
	"yaml-language-server",
	"html-lsp",
	"css-lsp",
	"typescript-language-server",
	"clangd",
	"rust-analyzer",
	"nixd",
	"stylua",
	"shfmt",
	"prettier",
	"prettierd",
	"ruff",
	"pyright",
	"black",
	"isort",
	"clang-format",
	"alejandra",
}

local function path_exists(path)
	return uv.fs_stat(path) ~= nil
end

local function marker_exists()
	return path_exists(done_marker)
end

local function welcome_marker_exists()
	return path_exists(welcome_marker)
end

local function write_marker(path)
	vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
	vim.fn.writefile({ os.date("!%Y-%m-%dT%H:%M:%SZ") }, path)
end

local function write_done_marker()
	write_marker(done_marker)
end

local welcome_ns = vim.api.nvim_create_namespace("ghostty_welcome")
local welcome_win = nil

local function close_startup_overlays(filetypes)
	local targets = filetypes or startup_overlay_filetypes
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local ok_buf, buf = pcall(vim.api.nvim_win_get_buf, win)
		if ok_buf and vim.api.nvim_buf_is_valid(buf) then
			local ft = vim.bo[buf].filetype
			if targets[ft] then
				pcall(vim.api.nvim_win_close, win, true)
			end
		end
	end
end

local function close_welcome_modal()
	if welcome_win and vim.api.nvim_win_is_valid(welcome_win) then
		pcall(vim.api.nvim_win_close, welcome_win, true)
	end
	welcome_win = nil
end

local function show_welcome(opts)
	opts = opts or {}
	local force = opts.force == true
	local already_shown = welcome_marker_exists()
	if not already_shown then
		write_marker(welcome_marker)
	elseif not force then
		return
	end

	vim.schedule(function()
		close_welcome_modal()

		local lines = {
			"Hello from Ghostty Neovim",
			"",
			"Ghostty managed Neovim profile is active (NvChad-based defaults for nvim-gui).",
			"If you stay on managed mode, edit your Neovim config in:",
			"~/.config/ghostty/nvim",
			"(same style/layout as a regular ~/.config/nvim folder)",
			"",
			"Want to use your own ~/.config/nvim instead?",
			"Set this in ~/.config/ghostty/config:",
			"neovim-gui-config-mode = user",
			"(If that line is commented out, remove the leading #.)",
			"",
			"Press <Enter>, q, or <Esc> to close",
		}

		local width = 70
		for _, line in ipairs(lines) do
			width = math.max(width, vim.fn.strdisplaywidth(line) + 4)
		end
		local max_width = math.max(40, vim.o.columns - 4)
		width = math.max(40, math.min(width, max_width))
		local height = math.min(#lines, math.max(8, vim.o.lines - 4))

		local row = math.max(1, math.floor((vim.o.lines - height) * 0.5) - 1)
		local col = math.max(0, math.floor((vim.o.columns - width) * 0.5))

		local buf = vim.api.nvim_create_buf(false, true)
		vim.bo[buf].bufhidden = "wipe"
		vim.bo[buf].buftype = "nofile"
		vim.bo[buf].swapfile = false
		vim.bo[buf].modifiable = true
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
		vim.bo[buf].modifiable = false
		vim.bo[buf].filetype = "ghosttywelcome"

		local win = vim.api.nvim_open_win(buf, true, {
			relative = "editor",
			style = "minimal",
			border = "rounded",
			width = width,
			height = height,
			row = row,
			col = col,
			zindex = 250,
			title = " Hello ",
			title_pos = "center",
			noautocmd = true,
		})
		welcome_win = win

		pcall(vim.api.nvim_set_hl, 0, "GhosttyWelcomeTitle", { fg = "#55d6ff", bold = true })
		pcall(vim.api.nvim_set_hl, 0, "GhosttyWelcomeHello", { fg = "#55d6ff", bold = true })
		pcall(vim.api.nvim_set_hl, 0, "GhosttyWelcomePath", { fg = "#8be9fd" })
		pcall(vim.api.nvim_set_hl, 0, "GhosttyWelcomeHint", { fg = "#a6adc8" })

		vim.wo[win].number = false
		vim.wo[win].relativenumber = false
		vim.wo[win].signcolumn = "no"
		vim.wo[win].wrap = false
		vim.wo[win].cursorline = false
		vim.wo[win].winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder,FloatTitle:GhosttyWelcomeTitle"

		vim.api.nvim_buf_set_extmark(buf, welcome_ns, 0, 0, { end_col = 5, hl_group = "GhosttyWelcomeHello" })
		vim.api.nvim_buf_set_extmark(buf, welcome_ns, 4, 0, { end_col = #lines[5], hl_group = "GhosttyWelcomePath" })
		vim.api.nvim_buf_set_extmark(buf, welcome_ns, 9, 0, { end_col = #lines[10], hl_group = "GhosttyWelcomePath" })
		vim.api.nvim_buf_set_extmark(buf, welcome_ns, 12, 0, { end_col = #lines[13], hl_group = "GhosttyWelcomeHint" })

		vim.keymap.set("n", "q", close_welcome_modal, { buffer = buf, silent = true })
		vim.keymap.set("n", "<Esc>", close_welcome_modal, { buffer = buf, silent = true })
		vim.keymap.set("n", "<CR>", close_welcome_modal, { buffer = buf, silent = true })
	end)
end

local function startup_overlay_visible()
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local ok_buf, buf = pcall(vim.api.nvim_win_get_buf, win)
		if ok_buf and vim.api.nvim_buf_is_valid(buf) then
			local ft = vim.bo[buf].filetype
			if startup_overlay_filetypes[ft] then
				return true
			end
		end
	end
	return false
end

local function get_mason_packages()
	local merged = {}
	local seen = {}
	local function add_many(pkgs)
		for _, pkg in ipairs(pkgs) do
			if type(pkg) == "string" and pkg ~= "" and not seen[pkg] then
				seen[pkg] = true
				table.insert(merged, pkg)
			end
		end
	end

	add_many(default_mason_packages)

	local ok, chadrc = pcall(require, "chadrc")
	if ok and type(chadrc) == "table" and chadrc.mason and type(chadrc.mason.pkgs) == "table" then
		add_many(chadrc.mason.pkgs)
	end
	return merged
end

local function is_install_noise(msg)
	local text = type(msg) == "string" and msg or tostring(msg or "")
	local patterns = {
		"[Ii]nstall",
		"[Dd]ownload",
		"[Ee]xtract",
		"[Rr]eceiv",
		"[Cc]lon",
		"[Cc]ompil",
		"[Uu]pdat",
		"[Pp]arser",
		"[Pp]ackage",
		"[Tt]reesitter",
		"[Mm]ason",
		"^%s*%d+/%d+",
		"%[%d+/%d+%]",
		"registry",
		"already installed",
	}
	for _, pat in ipairs(patterns) do
		if text:find(pat) then
			return true
		end
	end
	return false
end

local function disable_quiet_mode()
	if not quiet_state or not quiet_state.active then
		return
	end

	local original_notify = quiet_state.original_notify
	local suppressed = quiet_state.suppressed
	quiet_state.active = false

	if quiet_state.wrap_notify then
		vim.notify = quiet_state.original_notify
		vim.notify_once = quiet_state.original_notify_once
	end
	vim.api.nvim_echo = quiet_state.original_echo
	_G.print = quiet_state.original_print
	quiet_state = nil
	vim.g.ghostty_bootstrap_quiet = nil

	if suppressed > 0 and original_notify then
		original_notify(
			string.format("Ghostty bootstrap running quietly in background (%d install messages hidden).", suppressed),
			vim.log.levels.INFO
		)
	end
end

local function schedule_quiet_disable(delay_ms)
	if not quiet_state or not quiet_state.active then
		return
	end
	quiet_state.generation = quiet_state.generation + 1
	local generation = quiet_state.generation
	vim.defer_fn(function()
		if quiet_state and quiet_state.active and quiet_state.generation == generation then
			disable_quiet_mode()
		end
	end, delay_ms)
end

local function enable_quiet_mode()
	if quiet_state and quiet_state.active then
		schedule_quiet_disable(90000)
		return
	end

	local original_notify = vim.notify
	local original_notify_once = vim.notify_once
	local original_echo = vim.api.nvim_echo
	local original_print = _G.print
	local wrap_notify = package.loaded["noice"] == nil
	quiet_state = {
		active = true,
		generation = 0,
		suppressed = 0,
		original_notify = original_notify,
		original_notify_once = original_notify_once,
		original_echo = original_echo,
		original_print = original_print,
		wrap_notify = wrap_notify,
	}
	vim.g.ghostty_bootstrap_quiet = true

	if wrap_notify then
		vim.notify = function(msg, level, opts)
			level = level or vim.log.levels.INFO
			if quiet_state and quiet_state.active and level < vim.log.levels.WARN and is_install_noise(msg) then
				quiet_state.suppressed = quiet_state.suppressed + 1
				schedule_quiet_disable(90000)
				return
			end
			return original_notify(msg, level, opts)
		end

		vim.notify_once = function(msg, level, opts)
			level = level or vim.log.levels.INFO
			if quiet_state and quiet_state.active and level < vim.log.levels.WARN and is_install_noise(msg) then
				quiet_state.suppressed = quiet_state.suppressed + 1
				schedule_quiet_disable(90000)
				return
			end
			return original_notify_once(msg, level, opts)
		end
	end

	vim.api.nvim_echo = function(chunks, history, opts)
		local parts = {}
		if type(chunks) == "table" then
			for _, chunk in ipairs(chunks) do
				if type(chunk) == "table" and type(chunk[1]) == "string" then
					table.insert(parts, chunk[1])
				end
			end
		end
		local msg = table.concat(parts, "")
		if quiet_state and quiet_state.active and is_install_noise(msg) then
			quiet_state.suppressed = quiet_state.suppressed + 1
			schedule_quiet_disable(90000)
			return
		end
		return original_echo(chunks, history, opts)
	end

	_G.print = function(...)
		local parts = {}
		for i = 1, select("#", ...) do
			parts[#parts + 1] = tostring(select(i, ...))
		end
		local msg = table.concat(parts, " ")
		if quiet_state and quiet_state.active and is_install_noise(msg) then
			quiet_state.suppressed = quiet_state.suppressed + 1
			schedule_quiet_disable(90000)
			return
		end
		return original_print(...)
	end

	schedule_quiet_disable(180000)
end

local function run_bootstrap()
	enable_quiet_mode()
	close_startup_overlays({ lazy = true })

	local ok_lazy, lazy = pcall(require, "lazy")
	if ok_lazy then
		lazy.load({
			plugins = {
				"mason.nvim",
			},
		})
	end

	local ran_any = false
	local ran_mason = false

	local mason_packages = get_mason_packages()
	if vim.fn.exists(":MasonInstall") == 2 and #mason_packages > 0 then
		ran_any = true
		local ok = pcall(vim.cmd, "silent! noautocmd MasonInstall " .. table.concat(mason_packages, " "))
		if ok then
			ran_mason = true
		end
	end

	if ran_any and ran_mason then
		write_done_marker()
		vim.defer_fn(function()
			close_startup_overlays()
			show_welcome()
		end, 700)
	end
end

local function bootstrap_when_ready(max_attempts, delay_ms)
	local attempts = 0
	local function tick()
		if marker_exists() then
			return
		end

		if startup_overlay_visible() then
			vim.defer_fn(tick, math.max(delay_ms, 1000))
			return
		end

		attempts = attempts + 1
		local has_mason = vim.fn.exists(":MasonInstall") == 2

		if has_mason then
			run_bootstrap()
			return
		end

		if attempts < max_attempts then
			vim.defer_fn(tick, delay_ms)
		end
	end

	vim.defer_fn(tick, delay_ms)
end

local function start_bootstrap_once()
	if marker_exists() or bootstrap_start_scheduled then
		return
	end

	bootstrap_start_scheduled = true
	close_startup_overlays({ lazy = true })
	bootstrap_when_ready(40, 250)
end

function M.setup()
	if setup_done then
		return
	end
	vim.g.ghostty_bootstrap_setup_done = true
	setup_done = true

	if vim.fn.exists(":GhosttyBootstrap") == 0 then
		vim.api.nvim_create_user_command("GhosttyBootstrap", function()
			run_bootstrap()
		end, { desc = "Re-run Ghostty managed Neovim bootstrap installs" })
	end

	if vim.fn.exists(":GhosttyWelcome") == 0 then
		vim.api.nvim_create_user_command("GhosttyWelcome", function()
			show_welcome({ force = true })
		end, { desc = "Show Ghostty managed Neovim welcome message" })
	end

	if marker_exists() then
		return
	end

	local start_group = vim.api.nvim_create_augroup("ghostty_bootstrap_start", { clear = true })
	vim.api.nvim_create_autocmd("User", {
		group = start_group,
		pattern = "LazyDone",
		once = true,
		callback = start_bootstrap_once,
	})
	vim.api.nvim_create_autocmd("User", {
		group = start_group,
		pattern = "VeryLazy",
		once = true,
		callback = start_bootstrap_once,
	})

	-- Fallback when User events were already fired before this module initialized.
	vim.defer_fn(start_bootstrap_once, 12000)
end

return M
