pcall(function()
	require("bootstrap").setup()
end)

return {
	{
		"folke/noice.nvim",
		lazy = false,
		priority = 1000,
		dependencies = {
			"MunifTanjim/nui.nvim",
			"rcarriga/nvim-notify",
		},
		config = function()
			require("noice").setup({
				cmdline = {
					enabled = true,
					view = "cmdline_popup",
					format = {
						cmdline = { pattern = "^:", icon = "", lang = "vim" },
						search_down = { kind = "search", pattern = "^/", icon = " ", lang = "regex" },
						search_up = { kind = "search", pattern = "^%?", icon = " ", lang = "regex" },
						filter = { pattern = "^:%s*!", icon = "$", lang = "bash" },
						lua = { pattern = { "^:%s*lua%s+", "^:%s*lua%s*=%s*", "^:%s*=%s*" }, icon = "", lang = "lua" },
						help = { pattern = "^:%s*he?l?p?%s+", icon = "󰋖" },
					},
				},
				views = {
					cmdline_popup = {
						position = { row = "50%", col = "50%" },
						size = { width = 60, height = "auto" },
						border = { style = "rounded", padding = { 0, 1 } },
						win_options = {
							winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
						},
					},
					popupmenu = {
						relative = "editor",
						position = { row = "55%", col = "50%" },
						size = { width = 60, height = 10 },
						border = { style = "rounded", padding = { 0, 1 } },
					},
				},
				messages = {
					enabled = true,
					view = "mini",
					view_error = "mini",
					view_warn = "mini",
					view_history = "messages",
					view_search = "virtualtext",
				},
				lsp = {
					progress = { enabled = false },
					override = {
						["vim.lsp.util.convert_input_to_markdown_lines"] = true,
						["vim.lsp.util.stylize_markdown"] = true,
						["cmp.entry.get_documentation"] = true,
					},
					hover = { enabled = true },
					signature = { enabled = true },
					message = { enabled = true, view = "mini" },
				},
				presets = {
					bottom_search = false,
					command_palette = true,
					long_message_to_split = true,
					inc_rename = true,
					lsp_doc_border = true,
				},
				routes = {
					{
						filter = {
							cond = function()
								return vim.g.ghostty_bootstrap_quiet == true
							end,
							event = "msg_show",
						},
						opts = { skip = true },
					},
					{
						filter = {
							cond = function()
								return vim.g.ghostty_bootstrap_quiet == true
							end,
							any = {
								{ event = "notify", find = "[Ii]nstall" },
								{ event = "notify", find = "[Dd]ownload" },
								{ event = "notify", find = "[Mm]ason" },
								{ event = "notify", find = "[Pp]arser" },
								{ event = "msg_show", find = "[Ii]nstall" },
								{ event = "msg_show", find = "[Dd]ownload" },
								{ event = "msg_show", find = "[Mm]ason" },
								{ event = "msg_show", find = "[Pp]arser" },
							},
						},
						opts = { skip = true },
					},
				},
			})
		end,
	},

	{
		"rcarriga/nvim-notify",
		lazy = false,
		priority = 950,
		config = function()
			local bg = require("base46").get_theme_tb("base_30").black
			require("notify").setup({
				background_colour = bg,
				fps = 165,
				render = "wrapped-compact",
				stages = "fade_in_slide_out",
				timeout = 3000,
				top_down = true,
				max_width = 50,
				minimum_width = 30,
				on_open = function(win)
					vim.api.nvim_win_set_config(win, { border = "rounded" })
				end,
			})
			vim.notify = require("notify")
		end,
	},

	{
		"parkers0405/hlchunk.nvim",
		url = "https://github.com/parkers0405/hlchunk.nvim.git",
		branch = "main",
		event = "BufReadPost",
		config = function()
			local colors = require("base46").get_theme_tb("base_30")
			require("hlchunk").setup({
				chunk = {
					enable = true,
					use_treesitter = true,
					style = {
						{ fg = colors.blue },
						{ fg = colors.red },
					},
					chars = {
						horizontal_line = "─",
						vertical_line = "│",
						left_top = "╭",
						left_bottom = "╰",
						left_arrow = "─",
						right_arrow = ">",
					},
					delay = 50,
					duration = 100,
					node_type_styles = {
						["^func"] = { fg = colors.blue },
						["method"] = { fg = colors.blue },
						["^if"] = { fg = colors.purple },
						["else"] = { fg = colors.purple },
						["match"] = { fg = colors.purple },
						["^for"] = { fg = colors.yellow },
						["^while"] = { fg = colors.yellow },
						["do_block"] = { fg = colors.yellow },
						["try"] = { fg = colors.green },
						["except"] = { fg = colors.green },
						["catch"] = { fg = colors.green },
						["with"] = { fg = colors.green },
						["class"] = { fg = colors.red },
						["object"] = { fg = colors.cyan },
						["table"] = { fg = colors.cyan },
						["dictionary"] = { fg = colors.cyan },
					},
					exclude_filetypes = {
						NvimTree = true,
						help = true,
						dashboard = true,
						lazy = true,
						mason = true,
						notify = true,
						toggleterm = true,
						TelescopePrompt = true,
					},
				},
				indent = {
					enable = false,
				},
				line_num = {
					enable = false,
				},
				blank = {
					enable = false,
				},
			})
		end,
	},

	{
		"sindrets/diffview.nvim",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvim-tree/nvim-web-devicons",
		},
		cmd = {
			"DiffviewOpen",
			"DiffviewFileHistory",
			"DiffviewClose",
			"DiffviewToggleFiles",
			"DiffviewFocusFiles",
			"DiffviewRefresh",
		},
		opts = {
			enhanced_diff_hl = true,
		},
	},

	{
		"stevearc/conform.nvim",
		event = "BufWritePre",
		opts = function(_, opts)
			opts = opts or {}
			opts.formatters_by_ft = vim.tbl_deep_extend("force", opts.formatters_by_ft or {}, {
				lua = { "stylua" },
				python = { "ruff_format", "isort", "black" },
				javascript = { "prettierd", "prettier" },
				typescript = { "prettierd", "prettier" },
				javascriptreact = { "prettierd", "prettier" },
				typescriptreact = { "prettierd", "prettier" },
				json = { "prettierd", "prettier" },
				yaml = { "prettierd", "prettier" },
				html = { "prettierd", "prettier" },
				css = { "prettierd", "prettier" },
				scss = { "prettierd", "prettier" },
				markdown = { "prettierd", "prettier" },
				sh = { "shfmt" },
				bash = { "shfmt" },
				zsh = { "shfmt" },
				c = { "clang_format" },
				cpp = { "clang_format" },
				rust = { "rustfmt" },
				nix = { "alejandra", "nixfmt" },
			})
			opts.format_on_save = {
				timeout_ms = 5000,
				lsp_fallback = true,
			}
			return opts
		end,
	},

	{
		"neovim/nvim-lspconfig",
		event = "User FilePost",
		config = function()
			require("nvchad.configs.lspconfig").defaults()
			require("configs.lsp_defaults").setup()
		end,
	},

	{
		"rachartier/tiny-inline-diagnostic.nvim",
		event = "VeryLazy",
		priority = 900,
		config = function()
			require("tiny-inline-diagnostic").setup({
				preset = "modern",
				transparent_bg = true,
				transparent_cursorline = true,
				options = {
					show_source = { enabled = true, if_many = true },
					show_code = true,
					throttle = 20,
					enable_on_insert = false,
					multilines = { enabled = true, always_show = false },
					overflow = { mode = "wrap" },
				},
			})
		end,
	},

	{
		"nvim-telescope/telescope.nvim",
		opts = function(_, opts)
			opts = opts or {}
			opts.defaults = opts.defaults or {}
			opts.defaults.layout_strategy = "horizontal"
			opts.defaults.layout_config = vim.tbl_deep_extend("force", opts.defaults.layout_config or {}, {
				horizontal = {
					prompt_position = "top",
					preview_width = 0.55,
					results_width = 0.45,
				},
				width = 0.95,
				height = 0.85,
				preview_cutoff = 40,
			})
			opts.defaults.sorting_strategy = "ascending"

			opts.pickers = vim.tbl_deep_extend("force", opts.pickers or {}, {
				find_files = {
					layout_strategy = "horizontal",
					layout_config = { preview_width = 0.55 },
				},
				live_grep = {
					layout_strategy = "horizontal",
					layout_config = { preview_width = 0.55 },
				},
			})

			return opts
		end,
	},

	{
		"Bekaboo/dropbar.nvim",
		event = "VeryLazy",
		dependencies = {
			"nvim-telescope/telescope-fzf-native.nvim",
		},
		config = function()
			require("dropbar").setup({
				bar = {
					padding = { left = 1, right = 1 },
					pick = { pivots = "abcdefghijklmnopqrstuvwxyz" },
				},
				menu = {
					win_configs = {
						border = "rounded",
					},
				},
			})
		end,
	},
}
