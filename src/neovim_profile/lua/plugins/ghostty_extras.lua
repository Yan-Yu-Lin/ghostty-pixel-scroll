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

					local shader_picker_items = {
						{ label = "CRT Curved", value = "crt-curved" },
						{ label = "CRT Curve", value = "crt-curve" },
						{ label = "Green", value = "phosphor-green" },
						{ label = "Blue Grid", value = "blue-neon-grid" },
						{ label = "Amber", value = "amber-console" },
						{ label = "HUD", value = "hud-diagnostic" },
						{ label = "Green+Curve", value = "phosphor-green+crt-curve" },
						{ label = "Amber+Curve", value = "amber-console+crt-curve" },
						{ label = "Blue+Curve", value = "blue-neon-grid+crt-curve" },
						{ label = "HUD+Curve", value = "hud-diagnostic+crt-curve" },
						{ label = "None", value = "none" },
					}

					local function send_shader_preset(preset)
						local name = (preset and preset ~= "") and preset or "crt-curved"
						local chan = vim.g.ghostty_channel
						if type(chan) == "number" then
							local ok_info = pcall(vim.api.nvim_get_chan_info, chan)
							if ok_info then
								local ok_notify = pcall(vim.rpcnotify, chan, "ghostty_shader", name)
								if ok_notify then
									return
								end
							end
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
							vim.ui.select(shader_picker_items, {
								prompt = "Shader",
								format_item = function(item)
									return item.label
								end,
							}, function(choice)
								if choice then
									send_shader_preset(choice.value)
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
				local function is_opencode_term(bufnr)
					if not vim.api.nvim_buf_is_valid(bufnr) then
						return false
					end
					if vim.bo[bufnr].buftype ~= "terminal" then
						return false
					end
					local name = vim.api.nvim_buf_get_name(bufnr)
					return name:find("opencode", 1, true) ~= nil
				end

				local function remove_from_tabufline(bufnr)
					local removed = false
					for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
						local ok, bufs = pcall(function()
							return vim.t[tab].bufs
						end)
						if ok and type(bufs) == "table" then
							local filtered = {}
							for _, existing in ipairs(bufs) do
								if existing ~= bufnr then
									filtered[#filtered + 1] = existing
								else
									removed = true
								end
							end
							if #filtered ~= #bufs then
								pcall(function()
									vim.t[tab].bufs = filtered
								end)
							end
						end
					end
					if removed then
						pcall(vim.cmd, "redrawtabline")
					end
				end

				local function patch_opencode_term(bufnr)
					if not is_opencode_term(bufnr) then
						return
					end

					vim.bo[bufnr].filetype = "opencode_terminal"
					vim.bo[bufnr].buflisted = false
					vim.bo[bufnr].bufhidden = "hide"
					vim.bo[bufnr].swapfile = false
					remove_from_tabufline(bufnr)
					if vim.b[bufnr].ghostty_opencode_patched then
						return
					end

					vim.b[bufnr].ghostty_opencode_patched = true

					local map_opts = { buffer = bufnr, noremap = true, silent = true }

					vim.keymap.set("t", "<Esc>", "<Esc>", vim.tbl_extend("force", map_opts, { desc = "opencode: send esc" }))
					vim.keymap.set("t", "<C-h>", "<C-\\><C-N><C-w>h", vim.tbl_extend("force", map_opts, { desc = "opencode: move to left window" }))
					vim.keymap.set("t", "<C-j>", "<C-\\><C-N><C-w>j", vim.tbl_extend("force", map_opts, { desc = "opencode: move to lower window" }))
					vim.keymap.set("t", "<C-k>", "<C-\\><C-N><C-w>k", vim.tbl_extend("force", map_opts, { desc = "opencode: move to upper window" }))
					vim.keymap.set("t", "<C-l>", "<C-\\><C-N><C-w>l", vim.tbl_extend("force", map_opts, { desc = "opencode: move to right window" }))
					vim.keymap.set("n", "<C-h>", "<C-w>h", vim.tbl_extend("force", map_opts, { desc = "opencode: move left window" }))
					vim.keymap.set("n", "<C-j>", "<C-w>j", vim.tbl_extend("force", map_opts, { desc = "opencode: move lower window" }))
					vim.keymap.set("n", "<C-k>", "<C-w>k", vim.tbl_extend("force", map_opts, { desc = "opencode: move upper window" }))
					vim.keymap.set("n", "<C-l>", "<C-w>l", vim.tbl_extend("force", map_opts, { desc = "opencode: move right window" }))
					vim.keymap.set("t", "<A-Left>", "<C-\\><C-N>:vertical resize -2<CR>i", vim.tbl_extend("force", map_opts, { desc = "opencode: decrease window width" }))
					vim.keymap.set("t", "<A-Right>", "<C-\\><C-N>:vertical resize +2<CR>i", vim.tbl_extend("force", map_opts, { desc = "opencode: increase window width" }))
					vim.keymap.set("t", "<A-Up>", "<C-\\><C-N>:resize +2<CR>i", vim.tbl_extend("force", map_opts, { desc = "opencode: increase window height" }))
					vim.keymap.set("t", "<A-Down>", "<C-\\><C-N>:resize -2<CR>i", vim.tbl_extend("force", map_opts, { desc = "opencode: decrease window height" }))
					vim.keymap.set("t", "<C-\\><C-n>", "<Nop>", vim.tbl_extend("force", map_opts, { desc = "opencode: keep terminal mode" }))
					pcall(vim.keymap.del, "n", "<C-u>", { buffer = bufnr })
					pcall(vim.keymap.del, "n", "<C-d>", { buffer = bufnr })
					pcall(vim.keymap.del, "n", "gg", { buffer = bufnr })
					pcall(vim.keymap.del, "n", "G", { buffer = bufnr })
					pcall(vim.keymap.del, "n", "<Esc>", { buffer = bufnr })
					vim.keymap.set("n", "<Esc>", "i", vim.tbl_extend("force", map_opts, { desc = "opencode: back to terminal mode" }))
					for _, lhs in ipairs({
						"<ScrollWheelUp>",
						"<ScrollWheelDown>",
						"<ScrollWheelLeft>",
						"<ScrollWheelRight>",
						"<S-ScrollWheelUp>",
						"<S-ScrollWheelDown>",
						"<S-ScrollWheelLeft>",
						"<S-ScrollWheelRight>",
						"<C-ScrollWheelUp>",
						"<C-ScrollWheelDown>",
						"<C-ScrollWheelLeft>",
						"<C-ScrollWheelRight>",
						"<PageUp>",
						"<PageDown>",
						"<kPageUp>",
						"<kPageDown>",
					}) do
						-- In terminal mode, leave scrolling/clicking to opencode TUI.
						-- In terminal-normal mode, jump back to terminal mode so buffer doesn't scroll.
						vim.keymap.set("n", lhs, "i", map_opts)
					end
					vim.keymap.set("n", "<LeftMouse>", "i", map_opts)
					vim.keymap.set("n", "<LeftDrag>", "i", map_opts)
					for _, lhs in ipairs({
						"h",
						"j",
						"k",
						"l",
						"0",
						"$",
						"^",
						"gg",
						"G",
						"H",
						"M",
						"L",
						"zh",
						"zl",
						"zH",
						"zL",
						"<Left>",
						"<Right>",
						"<Up>",
						"<Down>",
						"<Home>",
						"<End>",
					}) do
						vim.keymap.set("n", lhs, "i", map_opts)
					end
				end

				local function target_opencode_width()
					return math.max(48, math.floor(vim.o.columns * 0.4))
				end

				local function sync_opencode_term_geometry(winid, bufnr)
					if not vim.api.nvim_win_is_valid(winid) then
						return
					end
					if not bufnr then
						bufnr = vim.api.nvim_win_get_buf(winid)
					end
					if not is_opencode_term(bufnr) then
						return
					end

					local job_id = vim.b[bufnr].terminal_job_id
					if type(job_id) == "number" and job_id > 0 then
						local ok_w, width = pcall(vim.api.nvim_win_get_width, winid)
						local ok_h, height = pcall(vim.api.nvim_win_get_height, winid)
						if ok_w and ok_h and width > 0 and height > 0 then
							pcall(vim.fn.jobresize, job_id, width, height)
						end
					end
					pcall(vim.cmd, "redraw!")
				end

				local function ensure_opencode_input_mode(winid, bufnr)
					if not vim.api.nvim_win_is_valid(winid) then
						return
					end
					if not bufnr then
						bufnr = vim.api.nvim_win_get_buf(winid)
					end
					if not is_opencode_term(bufnr) then
						return
					end

					if vim.api.nvim_get_current_win() ~= winid then
						pcall(vim.api.nvim_set_current_win, winid)
					end
					pcall(vim.cmd, "startinsert")
					vim.defer_fn(function()
						if vim.api.nvim_win_is_valid(winid) then
							local current_buf = vim.api.nvim_win_get_buf(winid)
							if is_opencode_term(current_buf) and vim.api.nvim_get_current_win() == winid then
								pcall(vim.cmd, "startinsert")
							end
						end
					end, 40)
				end

				local function style_opencode_window(winid)
					if not vim.api.nvim_win_is_valid(winid) then
						return
					end
					local ok_buf, bufnr = pcall(vim.api.nvim_win_get_buf, winid)
					if not ok_buf or not is_opencode_term(bufnr) then
						return
					end
					patch_opencode_term(bufnr)
					vim.wo[winid].winfixwidth = true
					vim.wo[winid].number = false
					vim.wo[winid].relativenumber = false
					vim.wo[winid].signcolumn = "no"
					vim.wo[winid].foldcolumn = "0"
					vim.wo[winid].statuscolumn = ""
					vim.wo[winid].cursorline = false
					vim.wo[winid].winbar = ""
					pcall(vim.api.nvim_set_option_value, "winfixbuf", true, { win = winid })
					local width = target_opencode_width()
					if vim.api.nvim_win_get_width(winid) ~= width then
						pcall(vim.api.nvim_win_set_width, winid, width)
					end
					sync_opencode_term_geometry(winid, bufnr)
				end

				local function find_opencode_win_in_current_tab()
					for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
						local bufnr = vim.api.nvim_win_get_buf(winid)
						if is_opencode_term(bufnr) then
							return winid, bufnr
						end
					end
				end

				local function focus_opencode_term()
					local winid = find_opencode_win_in_current_tab()
					if winid then
						style_opencode_window(winid)
						ensure_opencode_input_mode(winid)
						return winid
					end
					return nil
				end

				local function restyle_opencode_windows()
					for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
						for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
							style_opencode_window(winid)
						end
					end
				end

				local function toggle_opencode_sidebar()
					local winid = find_opencode_win_in_current_tab()
					if winid then
						local ok_cfg, cfg = pcall(require, "opencode.config")
						if ok_cfg and cfg and cfg.provider then
							cfg.provider.winid = winid
						end
						require("opencode").toggle()
						return
					end

					local ok_cfg, cfg = pcall(require, "opencode.config")
					if ok_cfg and cfg and cfg.provider and cfg.provider.opts then
						cfg.provider.opts.split = "right"
						cfg.provider.opts.width = target_opencode_width()
						if cfg.provider.winid and vim.api.nvim_win_is_valid(cfg.provider.winid) then
							local provider_tab = vim.api.nvim_win_get_tabpage(cfg.provider.winid)
							if provider_tab ~= vim.api.nvim_get_current_tabpage() then
								pcall(vim.api.nvim_win_hide, cfg.provider.winid)
								cfg.provider.winid = nil
							end
						end
					end

					require("opencode").toggle()
					vim.defer_fn(function()
						for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
							patch_opencode_term(bufnr)
						end
						local opened = focus_opencode_term()
						if opened then
							vim.defer_fn(function()
								style_opencode_window(opened)
								ensure_opencode_input_mode(opened)
							end, 40)
							vim.defer_fn(function()
								style_opencode_window(opened)
								ensure_opencode_input_mode(opened)
							end, 140)
						end
						restyle_opencode_windows()
					end, 80)
				end

				vim.g.opencode_opts = vim.tbl_deep_extend("force", vim.g.opencode_opts or {}, {
					provider = {
						enabled = "terminal",
						cmd = "opencode --port",
						terminal = {
							split = "right",
							width = target_opencode_width(),
						},
					},
					events = {
						reload = true,
					},
				})

				vim.o.autoread = true
				local augroup = vim.api.nvim_create_augroup("GhosttyOpencode", { clear = true })
				vim.api.nvim_create_autocmd({ "TermOpen", "TabEnter", "VimResized" }, {
					group = augroup,
					callback = function(ev)
						if ev.buf and ev.buf > 0 then
							patch_opencode_term(ev.buf)
						end
						restyle_opencode_windows()
					end,
				})
				vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
					group = augroup,
					callback = function(ev)
						if not ev.buf or ev.buf <= 0 or not is_opencode_term(ev.buf) then
							return
						end
						local winid = vim.api.nvim_get_current_win()
						style_opencode_window(winid)
						ensure_opencode_input_mode(winid, ev.buf)
					end,
				})
				vim.api.nvim_create_autocmd("ModeChanged", {
					group = augroup,
					pattern = "*:*",
					callback = function()
						local bufnr = vim.api.nvim_get_current_buf()
						if not is_opencode_term(bufnr) then
							return
						end
						local mode = vim.api.nvim_get_mode().mode
						if mode:sub(1, 1) == "t" then
							return
						end
						vim.schedule(function()
							if vim.api.nvim_get_current_buf() ~= bufnr or not vim.api.nvim_win_is_valid(0) then
								return
							end
							local winid = vim.api.nvim_get_current_win()
							style_opencode_window(winid)
							ensure_opencode_input_mode(winid, bufnr)
						end)
					end,
				})

				if vim.fn.exists(":OpenCode") == 0 then
					vim.api.nvim_create_user_command("OpenCode", function()
						toggle_opencode_sidebar()
					end, { desc = "Toggle opencode sidebar" })
				end

				if vim.fn.exists(":OpenCodeAsk") == 0 then
					vim.api.nvim_create_user_command("OpenCodeAsk", function(opts)
						local prompt = opts.args ~= "" and opts.args or "@this: "
						require("opencode").ask(prompt, { submit = true })
					end, { nargs = "*", desc = "Ask opencode" })
				end

				if vim.fn.exists(":OpenCodeSelect") == 0 then
					vim.api.nvim_create_user_command("OpenCodeSelect", function()
						require("opencode").select()
					end, { desc = "Open opencode action picker" })
				end

				vim.keymap.set("n", "<leader>oo", "<cmd>OpenCode<CR>", { desc = "Toggle opencode sidebar" })
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
