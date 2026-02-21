require("nvchad.options")

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

-- Keep a real statusline visible in nvim-gui even before plugin UI settles.
o.laststatus = 3
o.showmode = false
o.ruler = false

o.wrap = true
o.linebreak = true
o.breakindent = true
o.showbreak = "↪ "

o.virtualedit = "all"

o.sidescrolloff = 50
o.sidescroll = 1
o.scrolloff = 10

o.mouse = "a"
o.mousescroll = "ver:3,hor:3"
