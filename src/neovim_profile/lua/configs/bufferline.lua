local M = {}

local shell_names = {
	bash = true,
	fish = true,
	nu = true,
	pwsh = true,
	powershell = true,
	sh = true,
	zsh = true,
}

local special_terminal_names = {
	btop = "btop",
	gitui = "GitUI",
	htop = "htop",
	lazygit = "LazyGit",
	nvim = "Neovim",
	opencode = "OpenCode",
	yazi = "Yazi",
}

local hidden_buftypes = {
	nofile = true,
	prompt = true,
	quickfix = true,
}

local hidden_filetypes = {
	TelescopePrompt = true,
	ghosttywelcome = true,
	help = true,
	lazy = true,
	mason = true,
	noice = true,
	notify = true,
	qf = true,
}

local function basename(path)
	if not path or path == "" then
		return ""
	end

	path = path:gsub("[/\\]+$", "")
	return path:match("([^/\\]+)$") or path
end

local function titleize(word)
	if word == "" then
		return ""
	end

	return (word:gsub("^%l", string.upper))
end

local function terminal_label(buf)
	local path = buf.path ~= "" and buf.path or vim.api.nvim_buf_get_name(buf.bufnr)
	local cwd = path:match("^term://(.-)//%d+:")
	local cmd = path:match("//%d+:(.*)$") or path:match(":(.*)$") or ""

	if cwd and cwd ~= "" then
		cwd = basename(vim.fn.expand(cwd))
	else
		cwd = ""
	end

	cmd = vim.trim(cmd)
	local parts = vim.split(cmd, "%s+", { trimempty = true })
	local first = basename(parts[1] or "")

	local label = special_terminal_names[first]
	if not label then
		if first == "" or shell_names[first] then
			label = "Terminal"
		else
			label = titleize(first)
		end
	end

	if cwd ~= "" and cwd ~= label then
		return string.format("%s · %s", label, cwd)
	end

	return label
end

local function diagnostics_indicator(count, level, _, context)
	if context.buffer:current() then
		return ""
	end

	local icon = level:match("error") and "" or ""
	return string.format(" %s %d", icon, count)
end

local function custom_filter(bufnr)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return false
	end

	local bo = vim.bo[bufnr]
	if not bo.buflisted then
		return false
	end

	if hidden_buftypes[bo.buftype] then
		return false
	end

	if hidden_filetypes[bo.filetype] then
		return false
	end

	return true
end

local function ordered_buffers()
	local ok, bufferline = pcall(require, "bufferline")
	if ok and type(bufferline.get_elements) == "function" then
		local ok_elements, state = pcall(bufferline.get_elements)
		if ok_elements and type(state) == "table" and type(state.elements) == "table" then
			local result = {}
			for _, element in ipairs(state.elements) do
				if type(element) == "table" and vim.api.nvim_buf_is_valid(element.id) then
					table.insert(result, element.id)
				end
			end
			if #result > 0 then
				return result
			end
		end
	end

	local result = {}
	for _, info in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
		if vim.api.nvim_buf_is_valid(info.bufnr) then
			table.insert(result, info.bufnr)
		end
	end

	return result
end

local function replacement_buffer(bufnr)
	local bufs = ordered_buffers()
	for index, id in ipairs(bufs) do
		if id == bufnr then
			return bufs[index + 1] or bufs[index - 1]
		end
	end

	return nil
end

local function close_buffer(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	local replacement = replacement_buffer(bufnr)
	local wins = vim.fn.win_findbuf(bufnr)

	if not replacement then
		replacement = vim.api.nvim_create_buf(true, false)
	end

	for _, win in ipairs(wins) do
		if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == bufnr then
			pcall(vim.api.nvim_win_set_buf, win, replacement)
		end
	end

	local ok = pcall(vim.cmd, string.format("confirm bdelete %d", bufnr))
	if not ok and vim.api.nvim_buf_is_valid(bufnr) then
		pcall(vim.cmd, string.format("bdelete! %d", bufnr))
	end
end

local function hl(name)
	local ok, value = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
	if not ok then
		return {}
	end

	return value or {}
end

local function sync_bufferline_backgrounds()
	local normal = hl("Normal")
	local selected = hl("TabLineSel")
	local string = hl("String")

	local normal_bg = normal.bg
	local normal_fg = normal.fg
	local selected_bg = selected.bg or normal_bg
	local selected_fg = selected.fg or normal_fg
	local accent_fg = string.fg or selected_fg or normal_fg

	local function set(name, opts)
		pcall(vim.api.nvim_set_hl, 0, name, opts)
	end

	set("BufferLineFill", { bg = normal_bg })
	set("BufferLineBackground", { fg = normal_fg, bg = normal_bg })
	set("BufferLineBuffer", { fg = normal_fg, bg = normal_bg })
	set("BufferLineBufferVisible", { fg = normal_fg, bg = normal_bg })
	set("BufferLineCloseButton", { fg = normal_fg, bg = normal_bg })
	set("BufferLineCloseButtonVisible", { fg = normal_fg, bg = normal_bg })
	set("BufferLineModified", { fg = accent_fg, bg = normal_bg })
	set("BufferLineModifiedVisible", { fg = accent_fg, bg = normal_bg })
	set("BufferLineDuplicate", { fg = normal_fg, bg = normal_bg, italic = false })
	set("BufferLineDuplicateVisible", { fg = normal_fg, bg = normal_bg, italic = false })
	set("BufferLineTruncMarker", { fg = normal_fg, bg = normal_bg })
	set("BufferLineOffsetSeparator", { fg = normal_bg, bg = normal_bg })
	set("BufferLineSeparator", { fg = normal_bg, bg = normal_bg })
	set("BufferLineSeparatorVisible", { fg = normal_bg, bg = normal_bg })

	if selected_bg ~= nil then
		set("BufferLineBufferSelected", { fg = selected_fg, bg = selected_bg, bold = true })
		set("BufferLineCloseButtonSelected", { fg = selected_fg, bg = selected_bg })
		set("BufferLineModifiedSelected", { fg = accent_fg, bg = selected_bg })
		set("BufferLineDuplicateSelected", { fg = selected_fg, bg = selected_bg, italic = false })
		set("BufferLineIndicatorSelected", { fg = selected_fg, bg = selected_bg })
		set("BufferLineSeparatorSelected", { fg = selected_bg, bg = normal_bg })
	end
end

local configured = false

local function sync_bufferline_theme()
	pcall(function()
		require("nvchad.base46").load({ "bufferline" })
	end)

	sync_bufferline_backgrounds()
end

local function reapply_bufferline_theme()
	sync_bufferline_theme()
	vim.defer_fn(sync_bufferline_theme, 20)
	vim.defer_fn(sync_bufferline_theme, 120)
end

local function apply()
	local ok, bufferline = pcall(require, "bufferline")
	if not ok then
		return
	end

	vim.opt.showtabline = 2

	if not configured then
		bufferline.setup({
			options = {
				always_show_bufferline = true,
				auto_toggle_bufferline = false,
				close_command = close_buffer,
				right_mouse_command = close_buffer,
				diagnostics = "nvim_lsp",
				themable = true,
				diagnostics_indicator = diagnostics_indicator,
				hover = {
					delay = 120,
					enabled = true,
					reveal = { "close" },
				},
				indicator = {
					style = "none",
				},
				max_name_length = 28,
				max_prefix_length = 20,
				mode = "buffers",
				name_formatter = function(buf)
					if vim.bo[buf.bufnr].buftype == "terminal" then
						return terminal_label(buf)
					end

					if buf.name == "" or buf.name == "[No Name]" then
						return "Scratch"
					end

					return buf.name
				end,
				offsets = {
					{
						filetype = "NvimTree",
						separator = true,
						text = " Explorer ",
						text_align = "left",
					},
				},
				separator_style = { "", "" },
				show_buffer_close_icons = true,
				show_close_icon = false,
				sort_by = "insert_after_current",
				style_preset = {
					bufferline.style_preset.no_italic,
					bufferline.style_preset.no_bold,
				},
				tab_size = 24,
				truncate_names = true,
				custom_filter = custom_filter,
			},
		})

		configured = true
	end

	sync_bufferline_theme()
end

function M.setup()
	local group = vim.api.nvim_create_augroup("ghostty_bufferline_theme", { clear = true })
	vim.api.nvim_create_autocmd("ColorScheme", {
		group = group,
		callback = function()
			vim.schedule(reapply_bufferline_theme)
		end,
	})

	vim.api.nvim_create_autocmd("VimEnter", {
		group = group,
		callback = function()
			vim.schedule(reapply_bufferline_theme)
		end,
	})

	vim.api.nvim_create_autocmd("User", {
		group = group,
		pattern = { "BufferLineLoaded", "LazyDone", "NvThemeReload" },
		callback = function()
			vim.schedule(reapply_bufferline_theme)
		end,
	})

	apply()
	vim.schedule(reapply_bufferline_theme)
end

function M.cycle_next()
	vim.cmd("BufferLineCycleNext")
end

function M.cycle_prev()
	vim.cmd("BufferLineCyclePrev")
end

function M.close_current()
	close_buffer(vim.api.nvim_get_current_buf())
end

return M
