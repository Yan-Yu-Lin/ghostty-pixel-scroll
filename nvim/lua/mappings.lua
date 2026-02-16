require "nvchad.mappings"

local map = vim.keymap.set
local opts = { noremap = true, silent = true }

------------------------------------------------------------
-- 1. General quality-of-life ------------------------------
------------------------------------------------------------
map("n", ";", ":", { desc = "CMD: enter command mode" })
map("i", "jk", "<ESC>", { desc = "Exit insert mode" })

------------------------------------------------------------
-- 2. Wrapped-line navigation ------------------------------
------------------------------------------------------------
map({ "n", "v" }, "<Up>", "gkg^", opts)
map({ "n", "v" }, "<Down>", "gjg^", opts)

map("i", "<Up>", function()
  if vim.fn.pumvisible() == 1 then
    return "<C-p>"
  else
    return "<C-o>gk<C-o>g^"
  end
end, { expr = true, noremap = true, silent = true })

map("i", "<Down>", function()
  if vim.fn.pumvisible() == 1 then
    return "<C-n>"
  else
    return "<C-o>gj<C-o>g^"
  end
end, { expr = true, noremap = true, silent = true })

map("i", "<CR>", function()
  local virtcol = vim.fn.virtcol "."
  return "<CR>" .. string.rep(" ", math.max(virtcol - 1, 0))
end, { expr = true, noremap = true, silent = true })

------------------------------------------------------------
-- 3. Terminal navigation ----------------------------------
------------------------------------------------------------
map("t", "<C-h>", "<C-\\><C-N><C-w>h", { desc = "Terminal: to left window" })
map("t", "<C-l>", "<C-\\><C-N><C-w>l", { desc = "Terminal: to right window" })
map("t", "<C-j>", "<C-\\><C-N><C-w>j", { desc = "Terminal: to bottom window" })
map("t", "<C-k>", "<C-\\><C-N><C-w>k", { desc = "Terminal: to top window" })
map("t", "<Esc>", "<C-\\><C-n>", { desc = "Terminal: exit terminal mode" })

------------------------------------------------------------
-- 4. Split resizing ---------------------------------------
------------------------------------------------------------
map("n", "<A-Up>", ":resize +2<CR>", { desc = "Increase window height" })
map("n", "<A-Down>", ":resize -2<CR>", { desc = "Decrease window height" })
map("n", "<A-Left>", ":vertical resize -2<CR>", { desc = "Decrease window width" })
map("n", "<A-Right>", ":vertical resize +2<CR>", { desc = "Increase window width" })

------------------------------------------------------------
-- 5. Telescope / LSP search -------------------------------
------------------------------------------------------------
local builtin = require("telescope.builtin")
map("n", "<leader>fs", builtin.lsp_document_symbols, { desc = "Search symbols (semantic)" })
map("n", "<leader>fS", builtin.lsp_dynamic_workspace_symbols, { desc = "Search workspace symbols" })
map("n", "<leader>fr", builtin.lsp_references, { desc = "Find references" })
map("n", "<leader>fd", builtin.lsp_definitions, { desc = "Find definitions" })
map("n", "<leader>fi", builtin.lsp_implementations, { desc = "Find implementations" })

------------------------------------------------------------
-- 6. Code outline (Aerial) --------------------------------
------------------------------------------------------------
map("n", "<leader>a", "<cmd>AerialToggle!<CR>", { desc = "Toggle code outline" })

------------------------------------------------------------
-- 7. ast-grep pattern search ------------------------------
------------------------------------------------------------
map("n", "<leader>vp", function()
  require("custom.ast_search").live_pattern_search()
end, { desc = "Smart pattern search (LIVE)" })

map("n", "<leader>vc", function()
  require("custom.ast_search").find_collections()
end, { desc = "Find all collections" })

map("n", "<leader>va", function()
  require("custom.ast_search").find_auth_patterns()
end, { desc = "Find auth patterns" })

------------------------------------------------------------
-- 8. Bufferline / buffer management -----------------------
------------------------------------------------------------
map("n", "<Tab>", "<cmd>BufferLineCycleNext<CR>", { desc = "Next buffer" })
map("n", "<S-Tab>", "<cmd>BufferLineCyclePrev<CR>", { desc = "Previous buffer" })
map("n", "<leader>x", "<cmd>bp<bar>sp<bar>bn<bar>bd<CR>", { desc = "Close buffer" })

------------------------------------------------------------
-- 9. NvimTree toggle --------------------------------------
------------------------------------------------------------
map("n", "<C-j>", function()
  local current_ft = vim.bo.filetype
  if current_ft == "NvimTree" then
    vim.cmd("wincmd p")
  else
    require("nvim-tree.api").tree.focus()
  end
end, { desc = "Jump between tree and buffer" })

------------------------------------------------------------
-- 10. Terminal toggle -------------------------------------
------------------------------------------------------------
map("n", "<leader>h", function()
  require("nvchad.term").toggle({ pos = "sp", id = "htoggleTerm", size = 0.3 })
end, { desc = "Toggle horizontal terminal" })
map("n", "<leader>v", function()
  require("nvchad.term").toggle({ pos = "vsp", id = "vtoggleTerm", size = 0.3 })
end, { desc = "Toggle vertical terminal" })
