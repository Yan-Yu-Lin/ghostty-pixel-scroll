-- Smooth scrolling and animations for Neovim in Ghostty
--
-- - Ghostty handles pixel-level smooth scroll animation (spring physics)
-- - neoscroll: triggers viewport changes for Ctrl+D/U/F/B that Ghostty animates
-- - mini.animate: window animations (resize, open, close)
return {
  -- neoscroll: For Ctrl+D/U/F/B style scrolling
  -- These send multiple line scrolls which Ghostty will animate smoothly
  {
    "karb94/neoscroll.nvim",
    event = "VeryLazy",
    config = function()
      local neoscroll = require("neoscroll")

      neoscroll.setup({
        mappings = {}, -- Custom mappings below
        hide_cursor = false, -- Ghostty handles cursor
        stop_eof = true,
        respect_scrolloff = true,
        cursor_scrolls_alone = true,
        duration_multiplier = 1.0,
        easing = "linear", -- Linear works best with Ghostty's spring animation
        performance_mode = false,
      })

      -- Page/half-page scrolling
      -- Shorter durations since Ghostty adds its own 150ms spring animation
      local keymap = {
        ["<C-u>"] = function() neoscroll.ctrl_u({ duration = 100, easing = "linear" }) end,
        ["<C-d>"] = function() neoscroll.ctrl_d({ duration = 100, easing = "linear" }) end,
        ["<C-b>"] = function() neoscroll.ctrl_b({ duration = 150, easing = "linear" }) end,
        ["<C-f>"] = function() neoscroll.ctrl_f({ duration = 150, easing = "linear" }) end,
        ["<C-y>"] = function() neoscroll.scroll(-0.1, { move_cursor = false, duration = 50 }) end,
        ["<C-e>"] = function() neoscroll.scroll(0.1, { move_cursor = false, duration = 50 }) end,
        ["zt"] = function() neoscroll.zt({ half_win_duration = 100 }) end,
        ["zz"] = function() neoscroll.zz({ half_win_duration = 100 }) end,
        ["zb"] = function() neoscroll.zb({ half_win_duration = 100 }) end,
      }

      for key, func in pairs(keymap) do
        vim.keymap.set({ "n", "v", "x" }, key, func)
      end
    end,
  },

  -- mini.animate: Window animations only (not scroll - Ghostty handles that)
  {
    "echasnovski/mini.animate",
    event = "VeryLazy",
    config = function()
      local animate = require("mini.animate")

      animate.setup({
        cursor = { enable = false }, -- Ghostty handles cursor
        scroll = { enable = false }, -- Ghostty handles scroll animation
        resize = {
          enable = true,
          timing = animate.gen_timing.linear({ duration = 80, unit = "total" }),
        },
        open = {
          enable = true,
          timing = animate.gen_timing.linear({ duration = 120, unit = "total" }),
          winconfig = animate.gen_winconfig.wipe({ direction = "from_edge" }),
          winblend = animate.gen_winblend.linear({ from = 80, to = 100 }),
        },
        close = {
          enable = true,
          timing = animate.gen_timing.linear({ duration = 80, unit = "total" }),
          winconfig = animate.gen_winconfig.wipe({ direction = "to_edge" }),
          winblend = animate.gen_winblend.linear({ from = 100, to = 80 }),
        },
      })
    end,
  },

}
