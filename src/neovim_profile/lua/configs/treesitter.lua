local M = {}

local min_cli_version = { 0, 26, 1 }

local default_languages = {
	"bash",
	"c",
	"cpp",
	"css",
	"go",
	"html",
	"javascript",
	"json",
	"jsonc",
	"lua",
	"luadoc",
	"markdown",
	"markdown_inline",
	"nix",
	"printf",
	"python",
	"query",
	"regex",
	"rust",
	"toml",
	"tsx",
	"typescript",
	"vim",
	"vimdoc",
	"yaml",
	"zig",
}

local function parser_dir()
	return vim.fn.stdpath("data") .. "/site"
end

function M.tool_root()
	return vim.fn.stdpath("data") .. "/tools/tree-sitter"
end

local function tool_bin_dirs()
	local root = M.tool_root()
	return {
		root .. "/bin",
		root .. "/node_modules/.bin",
	}
end

local function prepend_path(dir)
	if vim.fn.isdirectory(dir) ~= 1 then
		return
	end

	local path = vim.env.PATH or ""
	local sep = package.config:sub(1, 1) == "\\" and ";" or ":"
	for entry in string.gmatch(path, "[^" .. sep .. "]+") do
		if entry == dir then
			return
		end
	end

	vim.env.PATH = dir .. (path ~= "" and (sep .. path) or "")
end

function M.ensure_tool_path()
	for _, dir in ipairs(tool_bin_dirs()) do
		prepend_path(dir)
	end
end

function M.cli_info()
	M.ensure_tool_path()
	if vim.fn.executable("tree-sitter") ~= 1 then
		return nil
	end

	local output = vim.trim(vim.fn.system({ "tree-sitter", "--version" }))
	if vim.v.shell_error ~= 0 then
		return nil
	end

	return {
		path = vim.fn.exepath("tree-sitter"),
		version = vim.version.parse(output),
	}
	end

function M.cli_ok()
	local info = M.cli_info()
	return info and vim.version.ge(info.version, min_cli_version) or false
end

function M.ensure_runtimepath()
	local dir = parser_dir()
	local rtp = vim.opt.runtimepath:get()
	if not vim.tbl_contains(rtp, dir) then
		vim.opt.runtimepath:prepend(dir)
	end
	return dir
end

function M.languages()
	local merged = {}
	local seen = {}

	local function add(items)
		if type(items) ~= "table" then
			return
		end
		for _, item in ipairs(items) do
			if type(item) == "string" and item ~= "" and not seen[item] then
				seen[item] = true
				table.insert(merged, item)
			end
		end
	end

	add(default_languages)

	local ok, chadrc = pcall(require, "chadrc")
	if ok and type(chadrc) == "table" and type(chadrc.treesitter) == "table" then
		add(chadrc.treesitter.ensure_installed)
	end

	return merged
end

function M.opts(existing)
	M.ensure_runtimepath()
	local opts = existing or {}
	opts.ensure_installed = M.languages()
	opts.auto_install = true
	opts.highlight = vim.tbl_deep_extend("force", opts.highlight or {}, {
		enable = true,
		additional_vim_regex_highlighting = false,
	})
	opts.parser_install_dir = parser_dir()
	return opts
end

return M
