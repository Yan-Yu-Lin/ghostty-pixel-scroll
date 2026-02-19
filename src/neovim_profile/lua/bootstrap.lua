local M = {}

local uv = vim.uv or vim.loop
local done_marker = vim.fn.stdpath("state") .. "/ghostty/bootstrap-v2.done"

local treesitter_languages = {
	"bash",
	"c",
	"cpp",
	"css",
	"dockerfile",
	"go",
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
	"sql",
	"toml",
	"tsx",
	"typescript",
	"vim",
	"vimdoc",
	"yaml",
	"zig",
}

local function marker_exists()
	return uv.fs_stat(done_marker) ~= nil
end

local function write_done_marker()
	vim.fn.mkdir(vim.fn.fnamemodify(done_marker, ":h"), "p")
	vim.fn.writefile({ os.date("!%Y-%m-%dT%H:%M:%SZ") }, done_marker)
end

local function get_mason_packages()
	local ok, chadrc = pcall(require, "chadrc")
	if ok and type(chadrc) == "table" and chadrc.mason and type(chadrc.mason.pkgs) == "table" then
		return chadrc.mason.pkgs
	end
	return {}
end

local function run_bootstrap()
	local ok_lazy, lazy = pcall(require, "lazy")
	if ok_lazy then
		lazy.load({
			plugins = {
				"mason.nvim",
				"nvim-treesitter",
			},
		})
	end

	local ran_any = false

	local mason_packages = get_mason_packages()
	if vim.fn.exists(":MasonInstall") == 2 and #mason_packages > 0 then
		ran_any = true
		vim.cmd("silent! MasonInstall " .. table.concat(mason_packages, " "))
	end

	if vim.fn.exists(":TSInstall") == 2 and #treesitter_languages > 0 then
		ran_any = true
		vim.cmd("silent! TSInstall " .. table.concat(treesitter_languages, " "))
	end

	if ran_any then
		write_done_marker()
		vim.schedule(function()
			vim.notify("Ghostty first-launch bootstrap started (Mason + Treesitter).", vim.log.levels.INFO)
		end)
	end
end

function M.setup()
	if marker_exists() then
		return
	end

	vim.api.nvim_create_autocmd("User", {
		pattern = "VeryLazy",
		once = true,
		callback = function()
			run_bootstrap()
		end,
	})

	vim.api.nvim_create_user_command("GhosttyBootstrap", function()
		run_bootstrap()
	end, { desc = "Re-run Ghostty managed Neovim bootstrap installs" })
end

return M
