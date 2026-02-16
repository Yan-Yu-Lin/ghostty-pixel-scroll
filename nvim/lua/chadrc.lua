-- This file needs to have same structure as nvconfig.lua
-- https://github.com/NvChad/ui/blob/v3.0/lua/nvconfig.lua
-- Please read that file to know all available options :(

---@type ChadrcConfig
local M = {}

M.base46 = {
  theme = "pastel_dark",
  transparency = false,
}

-- Apple-style rounded UI
M.ui = {
  cmp = {
    style = "default", -- default, flat_light, flat_dark, atom, atom_colored
    border_color = "grey_fg", -- only for style = "default"
    selected_item_bg = "colored", -- colored / simple
  },

  telescope = { style = "bordered" }, -- bordered / borderless

  statusline = {
    theme = "default", -- default/vscode/vscode_colored/minimal
    separator_style = "round", -- default/round/block/arrow
  },

  tabufline = {
    enabled = false, -- Disabled - using bufferline.nvim instead
  },
}

-- NvimTree with rounded borders
M.nvimtree = {
  git = { enable = true },
  renderer = {
    highlight_git = true,
    icons = { show = { git = true } },
  },
}

return M
