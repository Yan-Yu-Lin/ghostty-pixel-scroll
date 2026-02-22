local uv = vim.uv or vim.loop

local function exists(path)
	return uv.fs_stat(path) ~= nil
end

local app_data = vim.fn.stdpath("data")
local app_base46_cache = app_data .. "/base46/"
vim.g.base46_cache = app_base46_cache
vim.g.mapleader = " "

-- bootstrap lazy.nvim
local app_lazy_root = app_data .. "/lazy"
local app_lazypath = app_lazy_root .. "/lazy.nvim"
local lazypath = app_lazypath

if not exists(lazypath) then
	local repo = "https://github.com/folke/lazy.nvim.git"
	pcall(vim.fn.system, { "git", "clone", "--filter=blob:none", repo, "--branch=stable", app_lazypath })
	lazypath = app_lazypath
end

if exists(lazypath) then
	vim.opt.rtp:prepend(lazypath)
end

local ok_lazy_cfg, lazy_config = pcall(require, "configs.lazy")
if not ok_lazy_cfg then
	lazy_config = {}
end

local ok_lazy, lazy = pcall(require, "lazy")
if ok_lazy then
	lazy_config.root = lazy_config.root or app_lazy_root
	local lazy_root = lazy_config.root
	local specs = {}
	local nvchad_runtime = lazy_root .. "/NvChad/lua/nvchad/options.lua"
	local has_nvchad = exists(nvchad_runtime)

	if has_nvchad then
		table.insert(specs, {
			"NvChad/NvChad",
			lazy = false,
			branch = "v2.5",
			import = "nvchad.plugins",
		})
		local nvchad_blink_spec = lazy_root .. "/NvChad/lua/nvchad/blink/lazyspec.lua"
		if exists(nvchad_blink_spec) then
			table.insert(specs, { import = "nvchad.blink.lazyspec" })
		end
	else
		-- Fallback: avoid hard import errors when offline or before first install.
		table.insert(specs, {
			"NvChad/NvChad",
			lazy = true,
			branch = "v2.5",
		})
	end

	table.insert(specs, { import = "plugins" })
	lazy.setup(specs, lazy_config)
end

-- load NvChad generated UI cache
pcall(dofile, vim.g.base46_cache .. "defaults")
pcall(dofile, vim.g.base46_cache .. "statusline")

pcall(require, "options")
pcall(require, "nvchad.autocmds")
pcall(function()
	require("bootstrap").setup()
end)

vim.schedule(function()
	pcall(require, "mappings")
end)
