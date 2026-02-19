---@type ChadrcConfig
local M = {}

M.base46 = {
	theme = "catppuccin",
	transparency = false,
}

M.ui = {
	cmp = {
		style = "default",
		border_color = "grey_fg",
		selected_item_bg = "colored",
	},

	telescope = { style = "bordered" },

	statusline = {
		theme = "default",
		separator_style = "round",
	},

	tabufline = {
		enabled = true,
	},
}

M.nvimtree = {
	git = { enable = true },
	renderer = {
		highlight_git = true,
		icons = { show = { git = true } },
	},
}

-- Mason tools to install with :MasonInstallAll
M.mason = {
	pkgs = {
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
	},
}

return M
