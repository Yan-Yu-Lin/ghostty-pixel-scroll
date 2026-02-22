pcall(function()
	require("bootstrap").setup()
end)

local function ghostty_base30()
	local ok, base46 = pcall(require, "base46")
	if ok and type(base46) == "table" and type(base46.get_theme_tb) == "function" then
		local ok_colors, colors = pcall(base46.get_theme_tb, "base_30")
		if ok_colors and type(colors) == "table" then
			return colors
		end
	end

	return {
		black = "#101014",
		blue = "#61afef",
		red = "#e06c75",
		purple = "#c678dd",
		yellow = "#e5c07b",
		green = "#98c379",
		cyan = "#56b6c2",
	}
end

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
			local function set_noice_theme_links()
				local function get_hl(name)
					local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
					return ok and hl or {}
				end

				local normal = get_hl("Normal")
				local normal_float = get_hl("NormalFloat")
				local float_border = get_hl("FloatBorder")
				local float_title = get_hl("FloatTitle")
				local pmenu_sel = get_hl("PmenuSel")

				local popup_bg = normal_float.bg or normal.bg
				local popup_fg = normal_float.fg or normal.fg
				local border_fg = float_border.fg or popup_fg
				local title_fg = float_title.fg or popup_fg

				pcall(vim.api.nvim_set_hl, 0, "NoiceCmdlinePopup", {
					fg = popup_fg,
					bg = popup_bg,
					blend = 0,
				})
				pcall(vim.api.nvim_set_hl, 0, "NoiceCmdlinePopupBorder", {
					fg = border_fg,
					bg = popup_bg,
					blend = 0,
				})
				pcall(vim.api.nvim_set_hl, 0, "NoiceCmdlinePopupTitle", {
					fg = title_fg,
					bg = popup_bg,
					bold = float_title.bold,
					italic = float_title.italic,
					blend = 0,
				})
				pcall(vim.api.nvim_set_hl, 0, "NoiceCmdlineIcon", {
					fg = title_fg,
					bg = popup_bg,
					bold = float_title.bold,
					italic = float_title.italic,
					blend = 0,
				})
				pcall(vim.api.nvim_set_hl, 0, "NoicePopupmenu", {
					fg = popup_fg,
					bg = popup_bg,
					blend = 0,
				})
				pcall(vim.api.nvim_set_hl, 0, "NoicePopupmenuBorder", {
					fg = border_fg,
					bg = popup_bg,
					blend = 0,
				})

				if pmenu_sel.fg or pmenu_sel.bg then
					pcall(vim.api.nvim_set_hl, 0, "NoicePopupmenuSelected", {
						fg = pmenu_sel.fg,
						bg = pmenu_sel.bg,
						bold = pmenu_sel.bold,
						italic = pmenu_sel.italic,
						blend = 0,
					})
					pcall(vim.api.nvim_set_hl, 0, "BlinkCmpMenuSelection", {
						fg = pmenu_sel.fg,
						bg = pmenu_sel.bg,
						bold = pmenu_sel.bold,
						italic = pmenu_sel.italic,
						blend = 0,
					})
				else
					pcall(vim.api.nvim_set_hl, 0, "NoicePopupmenuSelected", { link = "CursorLine" })
					pcall(vim.api.nvim_set_hl, 0, "BlinkCmpMenuSelection", { link = "CursorLine" })
				end

				pcall(vim.api.nvim_set_hl, 0, "NoicePopupmenuMatch", { link = "Special" })
				pcall(vim.api.nvim_set_hl, 0, "NvimTreeCursorLine", { link = "CursorLine" })
				pcall(vim.api.nvim_set_hl, 0, "NvimTreeCursorLineNr", { link = "CursorLineNr" })
			end

			local noice_theme_group = vim.api.nvim_create_augroup("ghostty_noice_theme_links", { clear = true })
			vim.api.nvim_create_autocmd("ColorScheme", {
				group = noice_theme_group,
				callback = set_noice_theme_links,
			})
			vim.api.nvim_create_autocmd("FileType", {
				group = noice_theme_group,
				pattern = "NvimTree",
				callback = set_noice_theme_links,
			})
			vim.api.nvim_create_autocmd({ "VimEnter", "UIEnter", "CmdlineEnter" }, {
				group = noice_theme_group,
				callback = set_noice_theme_links,
			})

				local shader_presets = {
					"crt-curved",
					"crt-curve",
					"phosphor-green",
					"blue-neon-grid",
					"amber-console",
					"hud-diagnostic",
					"phosphor-green+crt-curve",
					"amber-console+crt-curve",
					"blue-neon-grid+crt-curve",
					"hud-diagnostic+crt-curve",
					"none",
				}

			local function send_shader_preset(preset)
				local name = (preset and preset ~= "") and preset or "crt-curved"

				local chan = vim.g.ghostty_channel
				if type(chan) == "number" then
					pcall(vim.rpcnotify, chan, "ghostty_shader", name)
					return
				end

				local ok, err = pcall(function()
					io.stdout:write(string.format("\27]1345;%s\7", name))
					io.stdout:flush()
				end)
				if not ok then
					vim.notify("Ghostty shader send failed: " .. tostring(err), vim.log.levels.WARN)
				end
			end

				if vim.fn.exists(":GhosttyShader") == 0 then
					vim.api.nvim_create_user_command("GhosttyShader", function(opts)
						local name = ""
						if opts.fargs and #opts.fargs > 0 then
							name = table.concat(opts.fargs, "+")
						else
							name = opts.args
						end
						send_shader_preset(name)
					end, {
						nargs = "*",
						complete = function()
							return shader_presets
						end,
						desc = "Set Ghostty shader preset",
					})
				end

			if vim.fn.exists(":GhosttyShaders") == 0 then
				vim.api.nvim_create_user_command("GhosttyShaders", function()
					vim.ui.select(shader_presets, { prompt = "Ghostty Shader" }, function(choice)
						if choice then
							send_shader_preset(choice)
						end
					end)
				end, { desc = "Pick Ghostty shader preset" })
			end

			require("noice").setup({
				cmdline = {
					enabled = true,
					view = "cmdline_popup",
					opts = {
						border = {
							text = { top = "" },
						},
					},
					format = {
						cmdline = { pattern = "^:", icon = " ", lang = "vim", title = "" },
						search_down = { kind = "search", pattern = "^/", icon = " ", lang = "regex", title = "" },
						search_up = { kind = "search", pattern = "^%?", icon = " ", lang = "regex", title = "" },
						filter = { pattern = "^:%s*!", icon = "$ ", lang = "bash", title = "" },
						lua = { pattern = { "^:%s*lua%s+", "^:%s*lua%s*=%s*", "^:%s*=%s*" }, icon = " ", lang = "lua", title = "" },
						help = { pattern = "^:%s*he?l?p?%s+", icon = "󰋖 ", title = "" },
					},
				},
				views = {
					cmdline_popup = {
						position = { row = "50%", col = "50%" },
						size = { width = "72%", height = "auto" },
						border = { style = "rounded", padding = { 0, 2 } },
						win_options = {
							winblend = 0,
							winhighlight = "Normal:NoiceCmdlinePopup,FloatBorder:NoiceCmdlinePopupBorder,FloatTitle:NoiceCmdlinePopupTitle",
						},
					},
					cmdline_popupmenu = {
						relative = "editor",
						position = { row = "56%", col = "50%" },
						size = { width = "72%", height = 10 },
						border = { style = "none", padding = { 0, 0 } },
						win_options = {
							winblend = 0,
							winhighlight = "Normal:NoicePopupmenu,Pmenu:NoicePopupmenu,FloatBorder:NoicePopupmenuBorder,CursorLine:NoicePopupmenuSelected,PmenuSel:NoicePopupmenuSelected,PmenuMatch:NoicePopupmenuMatch",
						},
					},
					popupmenu = {
						relative = "editor",
						position = { row = "56%", col = "50%" },
						size = { width = "72%", height = 10 },
						border = { style = "none", padding = { 0, 0 } },
						win_options = {
							winblend = 0,
							winhighlight = "Normal:NoicePopupmenu,Pmenu:NoicePopupmenu,FloatBorder:NoicePopupmenuBorder,CursorLine:NoicePopupmenuSelected,PmenuSel:NoicePopupmenuSelected,PmenuMatch:NoicePopupmenuMatch",
						},
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

			set_noice_theme_links()
			for _, ms in ipairs({ 50, 150, 300, 700 }) do
				vim.defer_fn(set_noice_theme_links, ms)
			end
		end,
		},

		{
			"nickjvandyke/opencode.nvim",
			version = "*",
			lazy = false,
			cond = function()
				return vim.fn.executable("opencode") == 1
			end,
			config = function()
				local function detect_opencode_theme()
					local name = (vim.g.colors_name or ""):lower()
					if name == "" then
						return "system"
					end

					local map = {
						{ "catppuccin", "catppuccin" },
						{ "tokyonight", "tokyonight" },
						{ "kanagawa", "kanagawa" },
						{ "gruvbox", "gruvbox" },
						{ "everforest", "everforest" },
						{ "rose-pine", "rose-pine" },
						{ "rosepine", "rose-pine" },
						{ "nightfox", "nightfox" },
						{ "onedark", "one-dark" },
						{ "one_dark", "one-dark" },
						{ "nord", "nord" },
						{ "ayu", "ayu" },
					}

					for _, entry in ipairs(map) do
						if name:find(entry[1], 1, true) then
							return entry[2]
						end
					end

					return "system"
				end

				local function build_provider_cmd(theme_name)
					local cfg = vim.json.encode({ theme = theme_name })
					return "OPENCODE_CONFIG_CONTENT=" .. vim.fn.shellescape(cfg) .. " opencode --port"
				end

				local function sync_opencode_theme()
					local theme_name = detect_opencode_theme()
					local cmd = build_provider_cmd(theme_name)

					vim.g.ghostty_opencode_theme = theme_name
					vim.g.opencode_opts = vim.tbl_deep_extend("force", vim.g.opencode_opts or {}, {
						auto_reload = true,
						provider = {
							cmd = cmd,
							enabled = "terminal",
						},
					})

					local ok_cfg, cfg = pcall(require, "opencode.config")
					if ok_cfg and type(cfg) == "table" and type(cfg.opts) == "table" then
						cfg.opts = vim.tbl_deep_extend("force", cfg.opts, {
							auto_reload = true,
							provider = {
								cmd = cmd,
								enabled = "terminal",
							},
						})
					end
				end

				sync_opencode_theme()

				local group = vim.api.nvim_create_augroup("ghostty_opencode_theme_sync", { clear = true })
				vim.api.nvim_create_autocmd("ColorScheme", {
					group = group,
					callback = sync_opencode_theme,
				})
			end,
		},

		{
			"rcarriga/nvim-notify",
			lazy = false,
			priority = 950,
			config = function()
				local bg = ghostty_base30().black
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
				local colors = ghostty_base30()
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
		cmd = { "ConformInfo" },
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
		"Saghen/blink.cmp",
		optional = true,
		lazy = false,
		opts = function(_, opts)
			opts = opts or {}

			local cmdline_width = math.max(60, math.floor(vim.o.columns * 0.72))
			local menu_width = math.max(40, cmdline_width - 2)

			opts.completion = opts.completion or {}
			opts.completion.menu = opts.completion.menu or {}
			opts.completion.menu.border = "none"
			opts.completion.menu.scrollbar = false
			opts.completion.menu.min_width = menu_width

			local existing_cmdline = opts.cmdline or {}
			opts.cmdline = vim.tbl_deep_extend("force", existing_cmdline, {
				keymap = vim.tbl_deep_extend("force", existing_cmdline.keymap or { preset = "cmdline" }, {
					["<Up>"] = { "select_prev", "fallback" },
					["<Down>"] = { "select_next", "fallback" },
					["<Tab>"] = { "select_and_accept", "fallback" },
				}),
				completion = {
					menu = {
						auto_show = true,
						draw = {
							columns = { { "label" } },
						},
					},
				},
			})

			return opts
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
