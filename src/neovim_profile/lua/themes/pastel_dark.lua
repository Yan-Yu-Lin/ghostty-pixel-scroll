-- pastelDark: Near-black background with soft pastel accents
-- Custom NvChad base46 theme

---@type Base46Table
local M = {}

M.base_30 = {
  white         = "#b5bcc9",
  black         = "#0a0a0a",   -- main bg
  darker_black  = "#050505",   -- sidebars, tree bg
  black2        = "#111111",   -- cursor line
  one_bg        = "#161616",
  one_bg2       = "#1a1a1a",   -- secondary bg
  one_bg3       = "#222222",
  grey          = "#545454",
  grey_fg       = "#545454",
  grey_fg2      = "#545454",
  light_grey    = "#545454",
  red           = "#ef8891",
  baby_pink     = "#fca2aa",
  pink          = "#f5a0c0",
  green         = "#9fe8c3",
  vibrant_green = "#9ce5c0",
  blue          = "#99aee5",
  nord_blue     = "#a3b8ef",
  yellow        = "#fbdf90",
  sun           = "#f5d595",
  purple        = "#c2a2e3",
  dark_purple   = "#b696d7",
  teal          = "#b5c3ea",
  orange        = "#EDA685",
  cyan          = "#abb9e0",
  line          = "#1a1a1a",
  statusline_bg = "#050505",
  lightbg       = "#1a1a1a",
  pmenu_bg      = "#99aee5",
  folder_bg     = "#99aee5",
}

M.base_16 = {
  base00 = "#0a0a0a",   -- bg
  base01 = "#111111",   -- lighter bg
  base02 = "#1a1a1a",   -- selection
  base03 = "#545454",   -- comments
  base04 = "#545454",   -- dark fg
  base05 = "#b5bcc9",   -- fg
  base06 = "#d3d9e4",   -- light fg
  base07 = "#d3d9e4",   -- lightest fg
  base08 = "#ef8891",   -- variables, tags
  base09 = "#EDA685",   -- integers, constants
  base0A = "#fbdf90",   -- classes, search
  base0B = "#9fe8c3",   -- strings
  base0C = "#b5c3ea",   -- support, regex
  base0D = "#99aee5",   -- functions
  base0E = "#c2a2e3",   -- keywords
  base0F = "#ef8891",   -- deprecated
}

M.type = "dark"

M.polish_hl = {
  treesitter = {
    ["@variable"] = { fg = M.base_30.white },
    ["@property"] = { fg = M.base_30.teal },
    ["@variable.builtin"] = { fg = M.base_30.red },
    ["@string"] = { fg = M.base_30.green },
    ["@function"] = { fg = M.base_30.blue },
    ["@function.call"] = { fg = M.base_30.blue },
    ["@keyword"] = { fg = M.base_30.purple },
    ["@constant"] = { fg = M.base_30.orange },
    ["@number"] = { fg = M.base_30.orange },
    ["@type"] = { fg = M.base_30.yellow },
  },
}

M = require("base46").override_theme(M, "pastel_dark")

return M
