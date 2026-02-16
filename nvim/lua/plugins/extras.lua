return {
  -- Render-markdown: Better markdown rendering
  {
    "MeanderingProgrammer/render-markdown.nvim",
    enabled = false,
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "echasnovski/mini.nvim",
    },
    lazy = false,
    config = function()
      require("render-markdown").setup {
        code = {
          enabled = true,
          sign = false,
          style = "none",      -- No background on code blocks
          border = "none",     -- No border either
          above = "",          -- No line above
          below = "",          -- No line below
          highlight = "",      -- No highlight group
        },
      }

      -- Bind the custom move task function to <leader>m
      vim.api.nvim_set_keymap(
        "n",
        "<leader>m",
        ":lua require('custom.tasks').move_completed_task()<CR>",
        { noremap = true, silent = true }
      )

      -- Automatically move completed tasks on save
      vim.api.nvim_create_autocmd("BufWritePre", {
        pattern = "*.md",
        callback = function()
          require("custom.tasks").move_completed_task()
        end,
      })
    end,
  },

  -- Tabby: AI code completion (lazy, enable when needed)
  {
    "TabbyML/vim-tabby",
    lazy = true,
    init = function()
      vim.g.tabby_agent_start_command = { "npx", "tabby-agent", "--stdio" }
      vim.g.tabby_inline_completion_trigger = "auto"
      vim.g.tabby_inline_completion_keybinding_accept = "<C-CR>"
    end,
  },

  -- Cord: Discord Rich Presence
  {
    "vyfor/cord.nvim",
    lazy = false,
    opts = {
      tooltip = "The Superior Text Editor",
      show_status = true,
      show_notifications = true,
      update_interval = 5,
      details_format = "{file} - {mode}",
      state_format = "Working on {filetype}",
      assets = {
        default = "neovim",
        lua = "lua",
        python = "python",
      },
      client_id = "1338754902427435019",
    },
    config = function(_, opts)
      require("cord").setup(opts)
    end,
  },



  -- Image Preview
  {
    "adelarsq/image_preview.nvim",
    lazy = false,
    config = function()
      require("image_preview").setup {
        mappings = {
          preview = "<leader>z",
        },
      }
    end,
  },
}
