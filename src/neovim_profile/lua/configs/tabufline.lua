local M = {}

local api = vim.api
local fn = vim.fn
local get_hl = api.nvim_get_hl
local get_opt = api.nvim_get_option_value
local set_hl = api.nvim_set_hl
local strep = string.rep

local state = {
	active_buf = nil,
}

local function tabufline_utils()
	return require("nvchad.tabufline.utils")
end

local function btn(...)
	return tabufline_utils().btn(...)
end

local function txt(...)
	return tabufline_utils().txt(...)
end

local function tabufline_opts()
	return require("nvconfig").ui.tabufline
end

local function blend(fg, bg, alpha)
	local function channel(shift)
		local a = bit.rshift(fg, shift) % 256
		local b = bit.rshift(bg, shift) % 256
		return math.floor(a * alpha + b * (1 - alpha) + 0.5)
	end

	return channel(16) * 0x10000 + channel(8) * 0x100 + channel(0)
end

local function filename(str)
	return str:match("([^/\\]+)[/\\]*$")
end

local function is_real_buffer(bufnr)
	if type(bufnr) ~= "number" or not api.nvim_buf_is_valid(bufnr) then
		return false
	end

	if fn.buflisted(bufnr) ~= 1 then
		return false
	end

	local opts = tabufline_opts()
	local filetype = get_opt("filetype", { buf = bufnr })
	if filetype == opts.treeOffsetFt then
		return false
	end

	local buftype = get_opt("buftype", { buf = bufnr })
	return buftype ~= "nofile" and buftype ~= "prompt" and buftype ~= "quickfix"
end

local function listed_buffers()
	local bufs = {}
	for _, bufnr in ipairs(vim.t.bufs or {}) do
		if type(bufnr) == "number" and api.nvim_buf_is_valid(bufnr) and get_opt("buflisted", { buf = bufnr }) then
			table.insert(bufs, bufnr)
		end
	end

	if #bufs == 0 then
		for _, bufnr in ipairs(api.nvim_list_bufs()) do
			if is_real_buffer(bufnr) then
				table.insert(bufs, bufnr)
			end
		end
		if #bufs > 0 then
			vim.t.bufs = bufs
		end
	end
	return bufs
end

local function displayed_buffer()
	local current = api.nvim_get_current_buf()
	if is_real_buffer(current) then
		state.active_buf = current
		return current
	end

	if is_real_buffer(state.active_buf) then
		return state.active_buf
	end

	for _, bufnr in ipairs(listed_buffers()) do
		if is_real_buffer(bufnr) then
			state.active_buf = bufnr
			return bufnr
		end
	end

	local bufs = listed_buffers()
	return bufs[1] or current
end

local function track_active_buffer()
	local current = api.nvim_get_current_buf()
	if is_real_buffer(current) then
		state.active_buf = current
	end
	pcall(vim.cmd, "redrawtabline")
end

local function get_file_tree_width()
	local opts = tabufline_opts()
	for _, win in pairs(api.nvim_tabpage_list_wins(0)) do
		if vim.bo[api.nvim_win_get_buf(win)].ft == opts.treeOffsetFt then
			return api.nvim_win_get_width(win)
		end
	end
	return 0
end

local function new_hl(group1, group2)
	local fg = get_hl(0, { name = group1, link = false }).fg
	local bg = get_hl(0, { name = "Tb" .. group2, link = false }).bg
	local name = group1 .. group2
	set_hl(0, name, { fg = fg, bg = bg })
	return "%#" .. name .. "#"
end

local function gen_unique_name(name, index, bufs)
	for i2, nr2 in ipairs(bufs) do
		local filepath = filename(api.nvim_buf_get_name(nr2))
		if index ~= i2 and filepath == name then
			return vim.fn.fnamemodify(api.nvim_buf_get_name(bufs[index]), ":h:t") .. "/" .. name
		end
	end
end

local function style_buf(nr, i, w, active_buf, bufs)
	local icon = "󰈚 "
	local is_curbuf = active_buf == nr
	local tb_hl_name = "BufO" .. (is_curbuf and "n" or "ff")
	local icon_hl = new_hl("DevIconDefault", tb_hl_name)

	local name = filename(api.nvim_buf_get_name(nr))
	name = name and (gen_unique_name(name, i, bufs) or name) or " No Name "

	if name ~= " No Name " then
		local ok_devicons, devicons = pcall(require, "nvim-web-devicons")
		if ok_devicons then
			local devicon, devicon_hl = devicons.get_icon(name)
			if devicon then
				icon = " " .. devicon .. " "
				icon_hl = new_hl(devicon_hl, tb_hl_name)
			end
		end
	end

	local pad = math.floor((w - #name - 5) / 2)
	pad = pad <= 0 and 1 or pad

	local maxname_len = w - 5
	name = string.sub(name, 1, maxname_len - 2) .. (#name > maxname_len and ".." or "")
	name = txt(name, tb_hl_name)
	name = strep(" ", pad - 1) .. (icon_hl .. icon .. name) .. strep(" ", pad - 1)

	local close_btn = btn(" 󰅖 ", nil, "KillBuf", nr)
	name = btn(name, nil, "GoToBuf", nr)

	local modified = get_opt("mod", { buf = nr })
	if is_curbuf then
		close_btn = modified and txt("  ", "BufOnModified") or txt(close_btn, "BufOnClose")
	else
		close_btn = modified and txt("  ", "BufOffModified") or txt(close_btn, "BufOffClose")
	end

	return txt(name .. close_btn, "BufO" .. (is_curbuf and "n" or "ff"))
end

local function style_empty_buf(w)
	local icon_hl = new_hl("DevIconDefault", "BufOn")
	local name = txt(" No Name ", "BufOn")
	local icon = icon_hl .. " 󰈚 "
	local total_len = 10
	local pad = math.floor((w - total_len) / 2)
	pad = pad <= 0 and 1 or pad
	return txt(strep(" ", pad - 1) .. icon .. name .. strep(" ", pad - 1), "BufOn")
end

local function available_space()
	local opts = tabufline_opts()
	local pieces = {}
	for _, key in ipairs(opts.order or {}) do
		if key ~= "buffers" and M.modules[key] then
			table.insert(pieces, M.modules[key]())
		end
	end
	local line = table.concat(pieces)
	local rendered = api.nvim_eval_statusline(line, { use_tabline = true })
	return vim.o.columns - rendered.width
end

local function apply_highlights()
	local normal = get_hl(0, { name = "Normal", link = false })
	local normal_nc = get_hl(0, { name = "NormalNC", link = false })
	local end_of_buffer = get_hl(0, { name = "EndOfBuffer", link = false })
	local sign_column = get_hl(0, { name = "SignColumn", link = false })
	local fold_column = get_hl(0, { name = "FoldColumn", link = false })
	local line_nr = get_hl(0, { name = "LineNr", link = false })
	local win_separator = get_hl(0, { name = "WinSeparator", link = false })
	local tree = get_hl(0, { name = "NvimTreeNormal", link = false })
	local tree_nc = get_hl(0, { name = "NvimTreeNormalNC", link = false })
	local tree_end = get_hl(0, { name = "NvimTreeEndOfBuffer", link = false })
	local tree_separator = get_hl(0, { name = "NvimTreeWinSeparator", link = false })
	local base_bg = normal.bg or get_hl(0, { name = "TbFill", link = false }).bg
	local tree_bg = tree.bg or base_bg
	local tree_fg = tree.fg or normal.fg
	local separator_fg = blend(normal.fg or tree_fg or 0xFFFFFF, base_bg, 0.14)

	set_hl(0, "NormalNC", { fg = normal_nc.fg or normal.fg, bg = base_bg })
	set_hl(0, "EndOfBuffer", { fg = end_of_buffer.fg or base_bg, bg = base_bg })
	set_hl(0, "SignColumn", { fg = sign_column.fg or line_nr.fg or normal.fg, bg = base_bg })
	set_hl(0, "FoldColumn", { fg = fold_column.fg or line_nr.fg or normal.fg, bg = base_bg })
	set_hl(0, "LineNr", { fg = line_nr.fg or normal.fg, bg = base_bg })
	set_hl(0, "WinSeparator", { fg = win_separator.fg or base_bg, bg = base_bg })
	set_hl(0, "VertSplit", { fg = win_separator.fg or base_bg, bg = base_bg })
	set_hl(0, "NvimTreeNormalNC", { fg = tree_nc.fg or tree_fg, bg = tree_bg })
	set_hl(0, "NvimTreeEndOfBuffer", { fg = tree_end.fg or tree_bg, bg = tree_bg })
	set_hl(0, "NvimTreeWinSeparator", { fg = separator_fg, bg = base_bg })
	set_hl(0, "GhosttyTabTreeOffset", { fg = tree_fg, bg = tree_bg })
	set_hl(0, "GhosttyTabTreeSeparator", { fg = separator_fg, bg = base_bg })
	set_hl(0, "GhosttyTabTreeGap", { fg = base_bg, bg = base_bg })
	set_hl(0, "GhosttyTabTreeGapEdge", { fg = base_bg, bg = tree_bg })
	pcall(vim.cmd, "redrawtabline")
end

M.modules = {}

M.modules.treeOffset = function()
	local width = get_file_tree_width()
	if width == 0 then
		return ""
	end

	return "%#GhosttyTabTreeOffset#" .. strep(" ", width) .. "%#GhosttyTabTreeSeparator#│"
end

M.modules.buffers = function()
	local opts = tabufline_opts()
	local bufs = listed_buffers()
	if #bufs == 0 then
		return style_empty_buf(opts.bufwidth) .. txt("%=", "Fill")
	end

	local active_buf = displayed_buffer()
	local buffers = {}
	local has_active = false

	for i, nr in ipairs(bufs) do
		if ((#buffers + 1) * opts.bufwidth) > available_space() then
			if has_active then
				break
			end
			table.remove(buffers, 1)
		end

		has_active = active_buf == nr or has_active
		table.insert(buffers, style_buf(nr, i, opts.bufwidth, active_buf, bufs))
	end

	return table.concat(buffers) .. txt("%=", "Fill")
end

function M.next()
	local bufs = listed_buffers()
	if #bufs == 0 then
		return
	end

	local active_buf = displayed_buffer()
	local index = vim.fn.index(bufs, active_buf)
	if index < 0 then
		api.nvim_set_current_buf(bufs[1])
		return
	end

	api.nvim_set_current_buf(bufs[(index + 1) % #bufs + 1])
end

function M.prev()
	local bufs = listed_buffers()
	if #bufs == 0 then
		return
	end

	local active_buf = displayed_buffer()
	local index = vim.fn.index(bufs, active_buf)
	if index < 0 then
		api.nvim_set_current_buf(bufs[1])
		return
	end

	api.nvim_set_current_buf(bufs[index == 0 and #bufs or index])
end

function M.close_buffer()
	require("nvchad.tabufline").close_buffer(displayed_buffer())
end

function M.setup()
	if vim.g.ghostty_tabufline_setup == 1 then
		return
	end

	vim.g.ghostty_tabufline_setup = 1
	vim.opt.showtabline = 2
	local group = api.nvim_create_augroup("ghostty_tabufline_focus", { clear = true })

	api.nvim_create_autocmd({ "BufEnter", "BufWinEnter", "TermOpen", "WinEnter" }, {
		group = group,
		callback = track_active_buffer,
	})

	api.nvim_create_autocmd({ "BufDelete", "ColorScheme", "UIEnter", "VimEnter" }, {
		group = group,
		callback = function()
			apply_highlights()
			track_active_buffer()
		end,
	})

	apply_highlights()
	track_active_buffer()
end

return M
