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

local function highlights(colors)
	return {
		fill = { bg = colors.darker_black },
		background = { fg = colors.grey_fg, bg = colors.darker_black },
		buffer = { fg = colors.light_grey, bg = colors.black },
		buffer_visible = { fg = colors.white, bg = colors.black },
		buffer_selected = { fg = colors.white, bg = colors.one_bg, bold = true },
		close_button = { fg = colors.grey_fg, bg = colors.black },
		close_button_visible = { fg = colors.light_grey, bg = colors.black },
		close_button_selected = { fg = colors.red, bg = colors.one_bg },
		modified = { fg = colors.sun, bg = colors.black },
		modified_visible = { fg = colors.sun, bg = colors.black },
		modified_selected = { fg = colors.sun, bg = colors.one_bg },
		duplicate = { fg = colors.grey, bg = colors.black, italic = false },
		duplicate_visible = { fg = colors.grey_fg, bg = colors.black, italic = false },
		duplicate_selected = { fg = colors.grey_fg2, bg = colors.one_bg, italic = false },
		separator = { fg = colors.black, bg = colors.darker_black },
		separator_visible = { fg = colors.black, bg = colors.darker_black },
		separator_selected = { fg = colors.one_bg, bg = colors.darker_black },
		indicator_selected = { fg = colors.blue, bg = colors.one_bg },
		trunc_marker = { fg = colors.blue, bg = colors.darker_black },
		offset_separator = { fg = colors.line, bg = colors.darker_black },
	}
end

local function apply()
	local ok, bufferline = pcall(require, "bufferline")
	if not ok then
		return
	end

	local colors = require("base46").get_theme_tb("base_30")

	vim.opt.showtabline = 2

	bufferline.setup({
		highlights = highlights(colors),
		options = {
			always_show_bufferline = true,
			auto_toggle_bufferline = false,
			close_command = close_buffer,
			right_mouse_command = close_buffer,
			diagnostics = "nvim_lsp",
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
end

function M.setup()
	local group = vim.api.nvim_create_augroup("ghostty_bufferline_theme", { clear = true })
	vim.api.nvim_create_autocmd("ColorScheme", {
		group = group,
		callback = function()
			vim.schedule(apply)
		end,
	})

	apply()
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
