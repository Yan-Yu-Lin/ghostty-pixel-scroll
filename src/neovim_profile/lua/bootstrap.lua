local M = {}

local uv = vim.uv or vim.loop
local done_marker = vim.fn.stdpath("state") .. "/ghostty/bootstrap-v4.done"
local setup_done = vim.g.ghostty_bootstrap_setup_done
local quiet_state = nil
local mason_bootstrap_requested = false
local treesitter_bootstrap_requested = false

local treesitter_languages = {
	"bash",
	"c",
	"cpp",
	"css",
	"html",
	"javascript",
	"json",
	"lua",
	"markdown",
	"markdown_inline",
	"nix",
	"python",
	"query",
	"rust",
	"toml",
	"tsx",
	"typescript",
	"vim",
	"vimdoc",
	"yaml",
	"zig",
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

local function marker_exists()
	return uv.fs_stat(done_marker) ~= nil
end

local function write_done_marker()
	vim.fn.mkdir(vim.fn.fnamemodify(done_marker, ":h"), "p")
	vim.fn.writefile({ os.date("!%Y-%m-%dT%H:%M:%SZ") }, done_marker)
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

	vim.notify = quiet_state.original_notify
	vim.notify_once = quiet_state.original_notify_once
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
	quiet_state = {
		active = true,
		generation = 0,
		suppressed = 0,
		original_notify = original_notify,
		original_notify_once = original_notify_once,
		original_echo = original_echo,
		original_print = original_print,
	}
	vim.g.ghostty_bootstrap_quiet = true

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

	local ok_lazy, lazy = pcall(require, "lazy")
	if ok_lazy then
		lazy.load({
			plugins = {
				"mason.nvim",
				"nvim-treesitter",
			},
		})
	end

	local ran_mason = false
	local ran_treesitter = false

	local mason_packages = get_mason_packages()
	local has_mason = vim.fn.exists(":MasonInstall") == 2
	if #mason_packages == 0 then
		ran_mason = true
	elseif has_mason then
		if mason_bootstrap_requested then
			ran_mason = true
		else
			local ok = pcall(vim.cmd, "silent! noautocmd MasonInstall " .. table.concat(mason_packages, " "))
			if ok then
				mason_bootstrap_requested = true
				ran_mason = true
			end
		end
	end

	local has_treesitter = vim.fn.exists(":TSInstall") == 2
	if #treesitter_languages == 0 then
		ran_treesitter = true
	elseif has_treesitter then
		if treesitter_bootstrap_requested then
			ran_treesitter = true
		else
			local ok = pcall(vim.cmd, "silent! noautocmd TSInstall " .. table.concat(treesitter_languages, " "))
			if ok then
				treesitter_bootstrap_requested = true
				ran_treesitter = true
			end
		end
	end

	local mason_done = (#mason_packages == 0) or (has_mason and ran_mason)
	local treesitter_done = (#treesitter_languages == 0) or (has_treesitter and ran_treesitter)
	if mason_done and treesitter_done then
		write_done_marker()
		vim.schedule(function()
			vim.notify("Ghostty first-launch setup started. Running quietly in background.", vim.log.levels.INFO)
		end)
		return true
	end

	return false
end

local function bootstrap_when_ready(max_attempts, delay_ms)
	local attempts = 0
	local function tick()
		if marker_exists() then
			return
		end

		attempts = attempts + 1
		if run_bootstrap() then
			return
		end

			if attempts < max_attempts then
				vim.defer_fn(tick, delay_ms)
			else
				vim.schedule(function()
					vim.notify(
						"Ghostty bootstrap did not finish automatically. Run :GhosttyBootstrap after Lazy/Mason loads.",
						vim.log.levels.WARN
					)
				end)
			end
		end

		vim.defer_fn(tick, delay_ms)
end

function M.setup()
	if setup_done then
		return
	end
	vim.g.ghostty_bootstrap_setup_done = true
	setup_done = true

	if marker_exists() then
		return
	end

	vim.api.nvim_create_user_command("GhosttyBootstrap", function()
		run_bootstrap()
	end, { desc = "Re-run Ghostty managed Neovim bootstrap installs" })

	-- Don't rely on VeryLazy timing; keep retrying while Lazy installs plugins.
	bootstrap_when_ready(180, 500)
end

return M
