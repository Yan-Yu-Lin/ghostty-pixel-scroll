require "nvchad.options"

------------------------------------------------------------
-- 1. Rounded borders for floating windows -----------------
------------------------------------------------------------
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

------------------------------------------------------------
-- 2. Editor settings --------------------------------------
------------------------------------------------------------
local o = vim.opt

o.fillchars = {
  horiz = "━",
  horizup = "┻",
  horizdown = "┳",
  vert = "┃",
  vertleft = "┫",
  vertright = "┣",
  verthoriz = "╋",
  eob = " ",
}

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

------------------------------------------------------------
-- 3. Neovide settings -------------------------------------
------------------------------------------------------------
if vim.g.neovide then
  vim.g.neovide_scroll_animation_length = 0.15
  vim.g.neovide_cursor_animation_length = 0.08
  vim.g.neovide_cursor_trail_size = 0.4
  vim.g.neovide_cursor_antialiasing = true
  vim.g.neovide_cursor_animate_command_line = true

  vim.g.neovide_hide_mouse_when_typing = true

  vim.g.neovide_floating_blur_amount_x = 2.0
  vim.g.neovide_floating_blur_amount_y = 2.0
  vim.g.neovide_floating_shadow = true

  vim.g.neovide_scale_factor = 1.0

  vim.g.neovide_text_gamma = 0.8
  vim.g.neovide_text_contrast = 0.1

  vim.g.neovide_refresh_rate = 165
  vim.g.neovide_refresh_rate_idle = 5

  vim.g.neovide_input_macos_option_key_is_meta = "only_left"

  vim.g.neovide_fullscreen = false
  vim.g.neovide_remember_window_size = true
end

------------------------------------------------------------
-- 4. Terminal colors & autocmds ---------------------------
------------------------------------------------------------
vim.g.terminal_color_0 = "#0a0a0a"
vim.g.terminal_color_8 = "#545454"
vim.g.terminal_color_1 = "#ef8891"
vim.g.terminal_color_9 = "#ef8891"
vim.g.terminal_color_2 = "#9fe8c3"
vim.g.terminal_color_10 = "#9ce5c0"
vim.g.terminal_color_3 = "#fbdf90"
vim.g.terminal_color_11 = "#f5d595"
vim.g.terminal_color_4 = "#99aee5"
vim.g.terminal_color_12 = "#a3b8ef"
vim.g.terminal_color_5 = "#c2a2e3"
vim.g.terminal_color_13 = "#b696d7"
vim.g.terminal_color_6 = "#b5c3ea"
vim.g.terminal_color_14 = "#abb9e0"
vim.g.terminal_color_7 = "#b5bcc9"
vim.g.terminal_color_15 = "#d3d9e4"

vim.api.nvim_create_autocmd("TermOpen", {
  callback = function()
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.signcolumn = "no"
    vim.opt_local.scrolloff = 0
    vim.cmd("startinsert")
  end,
})

vim.api.nvim_create_autocmd("BufEnter", {
  callback = function()
    if vim.bo.buftype == "terminal" then
      vim.opt_local.number = false
      vim.opt_local.relativenumber = false
      vim.opt_local.signcolumn = "no"
    end
  end,
})
