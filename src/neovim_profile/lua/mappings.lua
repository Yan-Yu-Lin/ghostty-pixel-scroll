require("nvchad.mappings")

local map = vim.keymap.set
local opts = { noremap = true, silent = true }

map("n", ";", ":", { desc = "Command mode" })
map("i", "jk", "<ESC>", { desc = "Exit insert mode" })

-- Wrapped-line aware cursor movement.
map({ "n", "v" }, "<Up>", "gkg^", opts)
map({ "n", "v" }, "<Down>", "gjg^", opts)

map("i", "<Up>", function()
	if vim.fn.pumvisible() == 1 then
		return "<C-p>"
	end
	return "<C-o>gk<C-o>g^"
end, { expr = true, noremap = true, silent = true })

map("i", "<Down>", function()
	if vim.fn.pumvisible() == 1 then
		return "<C-n>"
	end
	return "<C-o>gj<C-o>g^"
end, { expr = true, noremap = true, silent = true })

map("i", "<CR>", function()
	local virtcol = vim.fn.virtcol(".")
	return "<CR>" .. string.rep(" ", math.max(virtcol - 1, 0))
end, { expr = true, noremap = true, silent = true })

map("t", "<C-h>", "<C-\\><C-N><C-w>h", { desc = "Terminal left window" })
map("t", "<C-l>", "<C-\\><C-N><C-w>l", { desc = "Terminal right window" })
map("t", "<C-j>", "<C-\\><C-N><C-w>j", { desc = "Terminal lower window" })
map("t", "<C-k>", "<C-\\><C-N><C-w>k", { desc = "Terminal upper window" })
map("t", "<Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

map("n", "<A-Up>", ":resize +2<CR>", { desc = "Increase window height" })
map("n", "<A-Down>", ":resize -2<CR>", { desc = "Decrease window height" })
map("n", "<A-Left>", ":vertical resize -2<CR>", { desc = "Decrease window width" })
map("n", "<A-Right>", ":vertical resize +2<CR>", { desc = "Increase window width" })

local builtin = require("telescope.builtin")
map("n", "<leader>fs", builtin.lsp_document_symbols, { desc = "Search document symbols" })
map("n", "<leader>fS", builtin.lsp_dynamic_workspace_symbols, { desc = "Search workspace symbols" })
map("n", "<leader>fr", builtin.lsp_references, { desc = "Find references" })
map("n", "<leader>fd", builtin.lsp_definitions, { desc = "Find definitions" })
map("n", "<leader>fi", builtin.lsp_implementations, { desc = "Find implementations" })

map("n", "<Tab>", function()
	require("nvchad.tabufline").next()
end, { desc = "Next buffer" })

map("n", "<C-Tab>", function()
	require("nvchad.tabufline").prev()
end, { desc = "Previous buffer" })

map("n", "<leader>x", function()
	require("nvchad.tabufline").close_buffer()
end, { desc = "Close buffer" })

map("n", "<C-j>", function()
	local current_ft = vim.bo.filetype
	if current_ft == "NvimTree" then
		vim.cmd("wincmd p")
	else
		require("nvim-tree.api").tree.focus()
	end
end, { desc = "Jump between tree and buffer" })

map("n", "<leader>h", function()
	require("nvchad.term").toggle({ pos = "sp", id = "htoggleTerm", size = 0.3 })
end, { desc = "Toggle horizontal terminal" })

map("n", "<leader>v", function()
	require("nvchad.term").toggle({ pos = "vsp", id = "vtoggleTerm", size = 0.3 })
end, { desc = "Toggle vertical terminal" })

map("n", "<leader>gd", "<cmd>CodeDiff<CR>", { desc = "Open CodeDiff" })
