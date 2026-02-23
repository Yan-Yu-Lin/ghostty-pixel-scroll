require("nvchad.options")

-- NvChad's theme picker persists the selected theme by rewriting `lua/chadrc.lua`.
-- In managed/Nix-style setups that file may be read-only, so guard writes to avoid E5108 crashes.
pcall(function()
	local nvutils = require("nvchad.utils")
	if type(nvutils) ~= "table" or type(nvutils.replace_word) ~= "function" then
		return
	end

	nvutils.replace_word = function(old, new, filepath)
		filepath = filepath or (vim.fn.stdpath("config") .. "/lua/chadrc.lua")

		local read_handle = io.open(filepath, "r")
		if not read_handle then
			return
		end

		local content = read_handle:read("*all")
		read_handle:close()

		local pattern = tostring(old or ""):gsub("%-", "%%-")
		local next_content = content:gsub(pattern, tostring(new or ""))

		local write_handle, err = io.open(filepath, "w")
		if not write_handle then
			vim.schedule(function()
				vim.notify(
					("NvChad theme not persisted (cannot write %s: %s)"):format(filepath, tostring(err or "permission denied")),
					vim.log.levels.WARN
				)
			end)
			return
		end

		write_handle:write(next_content)
		write_handle:close()
	end
end)

local border = "rounded"

vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, {
	border = border,
	max_width = 80,
})

vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, {
	border = border,
	max_width = 80,
})

vim.diagnostic.config({
	float = {
		border = border,
		max_width = 80,
		source = "always",
		header = "",
		prefix = "",
	},
})

-- Neovim 0.11+ global float border default.
pcall(function()
	vim.o.winborder = border
end)

local o = vim.opt

o.wrap = true
o.linebreak = true
o.breakindent = true
o.showbreak = "↪ "
o.number = true
o.relativenumber = false

o.virtualedit = "all"

o.sidescrolloff = 50
o.sidescroll = 1
o.scrolloff = 10

o.mouse = "a"
o.mousescroll = "ver:3,hor:3"

local number_excluded_filetypes = {
	NvimTree = true,
	lazy = true,
	mason = true,
	notify = true,
	noice = true,
}

local number_excluded_buftypes = {
	terminal = true,
	prompt = true,
	quickfix = true,
	nofile = true,
}

local function refresh_line_numbers(bufnr)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	local ft = vim.bo[bufnr].filetype
	local bt = vim.bo[bufnr].buftype
	local is_floating = vim.api.nvim_win_get_config(0).relative ~= ""
	local enabled = not is_floating and not number_excluded_filetypes[ft] and not number_excluded_buftypes[bt]

	vim.wo.number = enabled
	vim.wo.relativenumber = false
end

local number_group = vim.api.nvim_create_augroup("ghostty_line_numbers", { clear = true })
vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter", "TermOpen" }, {
	group = number_group,
	callback = function(args)
		refresh_line_numbers(args.buf)
	end,
})

refresh_line_numbers(vim.api.nvim_get_current_buf())
