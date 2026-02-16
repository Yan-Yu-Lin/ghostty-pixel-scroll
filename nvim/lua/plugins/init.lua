return {
  -- ════════════════════════════════════════════════════════════════════════════
  -- APPLE-STYLE ROUNDED UI
  -- ════════════════════════════════════════════════════════════════════════════

  -- Noice: Rounded cmdline, messages, notifications (Apple-like popups)
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    dependencies = {
      "MunifTanjim/nui.nvim",
      "rcarriga/nvim-notify",
    },
    config = function()
      require("noice").setup {
        cmdline = {
          enabled = true,
          view = "cmdline_popup",
          format = {
            cmdline = { pattern = "^:", icon = "", lang = "vim" },
            search_down = { kind = "search", pattern = "^/", icon = " ", lang = "regex" },
            search_up = { kind = "search", pattern = "^%?", icon = " ", lang = "regex" },
            filter = { pattern = "^:%s*!", icon = "$", lang = "bash" },
            lua = { pattern = { "^:%s*lua%s+", "^:%s*lua%s*=%s*", "^:%s*=%s*" }, icon = "", lang = "lua" },
            help = { pattern = "^:%s*he?l?p?%s+", icon = "󰋖" },
          },
        },
        views = {
          cmdline_popup = {
            position = { row = "50%", col = "50%" }, -- True center
            size = { width = 60, height = "auto" },
            border = { style = "rounded", padding = { 0, 1 } },
            win_options = {
              winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
            },
          },
          popupmenu = {
            relative = "editor",
            position = { row = "55%", col = "50%" }, -- Below cmdline
            size = { width = 60, height = 10 },
            border = { style = "rounded", padding = { 0, 1 } },
          },
        },
        messages = {
          enabled = true,
          view = "mini",
          view_error = "mini",
          view_warn = "mini",
          view_history = "messages",
          view_search = "virtualtext",
        },
        lsp = {
          progress = { enabled = false }, -- Disable LSP progress (was showing duplicates)
          override = {
            ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
            ["vim.lsp.util.stylize_markdown"] = true,
            ["cmp.entry.get_documentation"] = true,
          },
          hover = { enabled = true },
          signature = { enabled = true },
          message = { enabled = true, view = "mini" }, -- Show LSP messages in mini view (bottom right)
        },
        presets = {
          bottom_search = false,
          command_palette = true,
          long_message_to_split = true,
          inc_rename = true,
          lsp_doc_border = true,
        },
      }
    end,
  },

  -- Nvim-notify: Beautiful rounded notifications
  {
    "rcarriga/nvim-notify",
    config = function()
      local bg = require("base46").get_theme_tb("base_30").black
      require("notify").setup {
        background_colour = bg,
        fps = 165,
        render = "wrapped-compact",
        stages = "fade_in_slide_out",
        timeout = 3000,
        top_down = true,
        max_width = 50,
        minimum_width = 30,
        on_open = function(win)
          vim.api.nvim_win_set_config(win, { border = "rounded" })
        end,
      }
      vim.notify = require "notify"
    end,
  },

  -- Tiny-glimmer: Subtle animations for yank, paste, undo/redo
  {
    "rachartier/tiny-glimmer.nvim",
    event = "VeryLazy",
    config = function()
      local colors = require("base46").get_theme_tb("base_30")
      require("tiny-glimmer").setup {
        enabled = true,
        default_animation = "fade",
        refresh_interval_ms = 6, -- ~165fps (1000/165 ≈ 6ms)
        animations = {
          fade = {
            max_duration = 300,
            chars_for_max_duration = 10,
            from_color = colors.blue,
            to_color = colors.black,
          },
        },
        -- Animate these operations
        overwrite = {
          yank = { enabled = true },
          paste = { enabled = true },
          undo = { enabled = true, animation = "fade" },
          redo = { enabled = true, animation = "fade" },
          search = { enabled = true },
        },
      }
    end,
  },

  -- Dropbar: IDE-like breadcrumbs/winbar (like VSCode/Xcode)
  {
    "Bekaboo/dropbar.nvim",
    event = "VeryLazy",
    dependencies = {
      "nvim-telescope/telescope-fzf-native.nvim",
    },
    config = function()
      require("dropbar").setup {
        bar = {
          padding = { left = 1, right = 1 },
          pick = { pivots = "abcdefghijklmnopqrstuvwxyz" },
        },
        menu = {
          win_configs = {
            border = "rounded",
          },
        },
      }
    end,
  },

  -- Indent-blankline: Clean indent guides
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    event = "VeryLazy",
    config = function()
      require("ibl").setup {
        indent = {
          char = "│",
          tab_char = "│",
        },
        scope = {
          enabled = false,
          show_start = false,
          show_end = false,
        },
        exclude = {
          filetypes = { "dashboard", "lazy", "mason", "help", "NvimTree" },
        },
      }
    end,
  },

  -- Todo-comments: Highlight and search TODOs
  {
    "folke/todo-comments.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      local colors = require("base46").get_theme_tb("base_30")
      require("todo-comments").setup {
        signs = true,
        keywords = {
          FIX = { icon = " ", color = "error", alt = { "FIXME", "BUG", "FIXIT", "ISSUE" } },
          TODO = { icon = " ", color = "info", alt = { "todo" } },
          HACK = { icon = " ", color = "warning" },
          WARN = { icon = " ", color = "warning", alt = { "WARNING", "XXX" } },
          PERF = { icon = " ", color = "default", alt = { "OPTIM", "PERFORMANCE", "OPTIMIZE" } },
          NOTE = { icon = " ", color = "hint", alt = { "INFO" } },
          TEST = { icon = "⏲ ", color = "test", alt = { "TESTING", "PASSED", "FAILED" } },
        },
        colors = {
          error = { "DiagnosticError", colors.red },
          warning = { "DiagnosticWarn", colors.yellow },
          info = { "DiagnosticInfo", colors.blue },
          hint = { "DiagnosticHint", colors.green },
          default = { "Identifier", colors.purple },
          test = { "Identifier", colors.cyan },
        },
      }

      -- Add to which-key
      local wk = require "which-key"
      wk.add {
        { "<leader>ft", "<cmd>TodoTelescope<cr>", desc = "📝 TODOs" },
      }
    end,
  },

  -- Bufferline: rounded buffer tabs (inherits theme colors)
  {
    "akinsho/bufferline.nvim",
    event = "VimEnter",
    priority = 100,
    version = "*",
    dependencies = "nvim-tree/nvim-web-devicons",
    config = function()
      require("bufferline").setup {
        options = {
          mode = "buffers",
          style_preset = {
            require("bufferline").style_preset.no_italic,
            require("bufferline").style_preset.no_bold,
          },
          themable = true,
          numbers = "none",
          close_command = "bdelete! %d",
          right_mouse_command = "bdelete! %d",
          left_mouse_command = "buffer %d",
          middle_mouse_command = nil,
          indicator = {
            style = "underline",
          },
          buffer_close_icon = "󰅖",
          modified_icon = "●",
          close_icon = "",
          left_trunc_marker = "",
          right_trunc_marker = "",
          max_name_length = 18,
          max_prefix_length = 15,
          truncate_names = true,
          tab_size = 18,
          diagnostics = false,
          offsets = {
            {
              filetype = "NvimTree",
              text = " ",
              highlight = "NvimTreeNormal",
              text_align = "left",
              padding = 1,
              separator = false,
            },
          },
          color_icons = true,
          show_buffer_icons = true,
          show_buffer_close_icons = true,
          show_close_icon = false,
          show_tab_indicators = false,
          show_duplicate_prefix = true,
          persist_buffer_sort = true,
          separator_style = { "", "" },
          enforce_regular_tabs = false,
          always_show_bufferline = true,
          hover = {
            enabled = true,
            delay = 150,
            reveal = { "close" },
          },
          sort_by = "insert_after_current",
        },
      }
    end,
  },

  -- Trouble: Better diagnostics panel
  {
    "folke/trouble.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    cmd = "Trouble",
    config = function()
      require("trouble").setup {
        position = "bottom",
        height = 10,
        width = 50,
        icons = true,
        mode = "workspace_diagnostics",
        fold_open = "",
        fold_closed = "",
        group = true,
        padding = true,
        cycle_results = true,
        action_keys = {
          close = "q",
          cancel = "<esc>",
          refresh = "r",
          jump = { "<cr>", "<tab>" },
          open_split = { "<c-x>" },
          open_vsplit = { "<c-v>" },
          open_tab = { "<c-t>" },
          jump_close = { "o" },
          toggle_mode = "m",
          toggle_preview = "P",
          hover = "K",
          preview = "p",
          close_folds = { "zM", "zm" },
          open_folds = { "zR", "zr" },
          toggle_fold = { "zA", "za" },
          previous = "k",
          next = "j",
        },
        indent_lines = true,
        auto_open = false,
        auto_close = false,
        auto_preview = true,
        auto_fold = false,
        auto_jump = { "lsp_definitions" },
        use_diagnostic_signs = true,
      }

      -- Add to which-key
      local wk = require "which-key"
      wk.add {
        { "<leader>d", group = "🚨 Diagnostics" },
        { "<leader>dd", "<cmd>Trouble diagnostics toggle<cr>", desc = "📋 All Diagnostics" },
        { "<leader>df", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "📄 Document Diagnostics" },
        { "<leader>dl", "<cmd>Trouble loclist toggle<cr>", desc = "📍 Location List" },
        { "<leader>dq", "<cmd>Trouble qflist toggle<cr>", desc = "🔍 Quickfix List" },
      }
    end,
  },

  -- Dressing.nvim: Rounded vim.ui.input and vim.ui.select
  {
    "stevearc/dressing.nvim",
    event = "VeryLazy",
    config = function()
      require("dressing").setup {
        input = {
          enabled = true,
          default_prompt = "➤ ",
          prompt_align = "left",
          insert_only = true,
          start_in_insert = true,
          border = "rounded",
          relative = "cursor",
          prefer_width = 40,
          win_options = {
            winblend = 0,
            winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
          },
        },
        select = {
          enabled = true,
          backend = { "telescope", "builtin" },
          builtin = {
            border = "rounded",
            relative = "editor",
            win_options = {
              winblend = 0,
              winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
            },
          },
        },
      }
    end,
  },

  -- Which-Key: Epic leader menu with emojis, groups, animations
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    config = function()
      local wk = require "which-key"
      wk.setup {
        preset = "classic",
        plugins = {
          marks = true,
          registers = true,
          spelling = {
            enabled = true,
            suggestions = 20,
          },
          presets = {
            operators = true,
            motions = true,
            text_objects = true,
            windows = true,
            nav = true,
            z = true,
            g = true,
          },
        },
        icons = {
          breadcrumb = "»",
          separator = "➜",
          group = "+",
        },
        win = {
          border = "rounded",
          row = math.huge, -- Position at bottom
          col = 0,
          padding = { 2, 2 },
        },
        layout = {
          width = { min = 20, max = 50 },
          spacing = 3,
        },
      }

      -- Add custom groups with emojis
      wk.add {
        -- Files group
        { "<leader>f", group = "🔍 Find" },
        { "<leader>ff", desc = "📁 Files" },
        { "<leader>fa", desc = "📝 All Files" },
        { "<leader>fw", desc = "🔎 Words" },
        { "<leader>fb", desc = "📚 Buffers" },
        { "<leader>fh", desc = "📖 Help" },
        { "<leader>fo", desc = "📂 Old Files" },
        { "<leader>fz", desc = "🎯 Current Buffer" },

        -- Git group
        { "<leader>g", group = "🌿 Git" },
        { "<leader>gc", desc = "💬 Commits" },
        { "<leader>gs", desc = "📊 Status" },

        -- LSP group
        { "<leader>l", group = "💡 LSP" },
        { "<leader>la", desc = "⚡ Code Action" },
        { "<leader>ld", desc = "📋 Definition" },
        { "<leader>lf", desc = "🎨 Format" },
        { "<leader>li", desc = "ℹ️  Info" },
        { "<leader>lr", desc = "🔄 Rename" },
        { "<leader>ls", desc = "🔍 References" },

        -- Buffer group
        { "<leader>b", group = "📄 Buffers" },
        { "<leader>bn", desc = "➡️  Next" },
        { "<leader>bp", desc = "⬅️  Previous" },
        { "<leader>bd", desc = "❌ Delete" },

        -- Window group
        { "<leader>w", group = "🪟 Window" },
        { "<leader>wh", desc = "⬅️  Left" },
        { "<leader>wj", desc = "⬇️  Down" },
        { "<leader>wk", desc = "⬆️  Up" },
        { "<leader>wl", desc = "➡️  Right" },
        { "<leader>ws", desc = "➖ Split Horizontal" },
        { "<leader>wv", desc = "➗ Split Vertical" },
        { "<leader>wc", desc = "❌ Close" },

        -- Terminal group
        { "<leader>t", group = "💻 Terminal" },
        { "<leader>tf", desc = "🔲 Float" },
        { "<leader>tv", desc = "➗ Vertical" },

        -- NvimTree
        { "<leader>e", desc = "🌳 Explorer" },

        -- Misc
        { "<leader>n", desc = "🔢 Line Numbers" },
        { "<leader>rn", desc = "🔢 Relative Numbers" },
        { "<leader>ch", desc = "📋 Cheatsheet" },
        { "<leader>fm", desc = "🎨 Format" },
      }
    end,
  },

  -- ════════════════════════════════════════════════════════════════════════════
  -- ORIGINAL PLUGINS
  -- ════════════════════════════════════════════════════════════════════════════

  {
    "stevearc/conform.nvim",
    event = "BufWritePre", -- enabled format on save
    config = function()
      require "configs.conform"
    end,
  },

  -- Custom LSP config - extends NvChad's lspconfig (adds pyright, ruff, nixd, etc.)
  -- NvChad already loads nvim-lspconfig, we just hook into it
  {
    "neovim/nvim-lspconfig",
    config = function()
      require("nvchad.configs.lspconfig").defaults() -- NvChad's defaults (lua_ls)
      require "configs.lspconfig" -- Our additional servers
    end,
  },

  -- Tiny inline diagnostics - clean inline display without virtual lines
  {
    "rachartier/tiny-inline-diagnostic.nvim",
    event = "VeryLazy",
    priority = 1000,
    config = function()
      require("tiny-inline-diagnostic").setup {
        preset = "modern",
        transparent_bg = true,
        transparent_cursorline = true,
        hi = {
          error = "DiagnosticError",
          warn = "DiagnosticWarn",
          info = "DiagnosticInfo",
          hint = "DiagnosticHint",
          arrow = "NonText",
          background = "CursorLine",
          mixing_color = "None",
        },
        options = {
          show_source = { enabled = true, if_many = true },
          show_code = true,
          throttle = 20,
          softwrap = 40,
          multilines = { enabled = true, always_show = false },
          show_all_diags_on_cursorline = true,
          enable_on_insert = false,
          overflow = { mode = "wrap" },
          virt_texts = { priority = 2048 },
        },
      }
    end,
  },

  -- nvim-treesitter: lazy.nvim manages it (new API - no .configs)
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      -- Modern treesitter API (post-refactor)
      require("nvim-treesitter").setup()

      -- Install parsers for your languages
      require("nvim-treesitter").install {
        "vim",
        "lua",
        "vimdoc",
        "html",
        "css",
        "python",
        "c_sharp",
        "tsx",
        "javascript",
        "json",
        "toml",
        "typescript",
        "nix",
        "bash",
      }
    end,
  },

  -- Telescope fzf-native for blazing fast fuzzy finding
  {
    "nvim-telescope/telescope-fzf-native.nvim",
    build = "make",
  },

  -- Enhanced Telescope with semantic search via LSP
  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "telescope-fzf-native.nvim",
    },
    config = function()
      local actions = require "telescope.actions"
      require("telescope").setup {
        extensions = {
          fzf = {
            fuzzy = true,
            override_generic_sorter = true,
            override_file_sorter = true,
            case_mode = "smart_case",
          },
        },
        defaults = {
          file_ignore_patterns = { "node_modules", ".git/", "dist/" },
          -- Apple-style rounded borders
          borderchars = {
            prompt = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
            results = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
            preview = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
          },
          prompt_prefix = "   ",
          selection_caret = "  ",
          entry_prefix = "  ",
          -- HORIZONTAL layout: search top, results left, preview RIGHT
          layout_strategy = "horizontal",
          layout_config = {
            horizontal = {
              prompt_position = "top",
              preview_width = 0.55, -- Preview takes 55% width on RIGHT
              results_width = 0.45, -- Results take 45% width on LEFT
            },
            width = 0.95,
            height = 0.85,
            preview_cutoff = 40, -- Always show preview
          },
          sorting_strategy = "ascending",
          winblend = 0,
        },
        pickers = {
          -- Live grep: WITH preview on right
          live_grep = {
            layout_strategy = "horizontal",
            layout_config = {
              preview_width = 0.55,
            },
          },
          -- Git status: show diff on right
          git_status = {
            layout_strategy = "horizontal",
            layout_config = {
              preview_width = 0.6, -- Larger preview for diffs
            },
          },
          -- Git commits
          git_commits = {
            layout_strategy = "horizontal",
            layout_config = {
              preview_width = 0.6,
            },
          },
          -- Find files
          find_files = {
            layout_strategy = "horizontal",
            layout_config = {
              preview_width = 0.55,
            },
          },
        },
      }
      require("telescope").load_extension "fzf"
    end,
  },

  -- Aerial for code outline/structure view
  {
    "stevearc/aerial.nvim",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
    },
    config = function()
      require("aerial").setup {
        backends = { "treesitter", "lsp", "markdown" },
        layout = {
          max_width = { 40, 0.2 },
          min_width = 10,
        },
        on_attach = function(bufnr)
          vim.keymap.set("n", "{", "<cmd>AerialPrev<CR>", { buffer = bufnr })
          vim.keymap.set("n", "}", "<cmd>AerialNext<CR>", { buffer = bufnr })
        end,
      }
    end,
  },

  -- ════════════════════════════════════════════════════════════════════════════
  -- AESTHETIC ENHANCEMENTS
  -- ════════════════════════════════════════════════════════════════════════════

  -- Rainbow delimiters - colorful matching brackets
  {
    "HiPhish/rainbow-delimiters.nvim",
    event = "BufReadPost",
    config = function()
      local rainbow = require "rainbow-delimiters"
      local colors = require("base46").get_theme_tb("base_30")
      vim.g.rainbow_delimiters = {
        strategy = {
          [""] = rainbow.strategy["global"],
          vim = rainbow.strategy["local"],
        },
        query = {
          [""] = "rainbow-delimiters",
          lua = "rainbow-blocks",
        },
        highlight = {
          "RainbowDelimiterRed",
          "RainbowDelimiterYellow",
          "RainbowDelimiterBlue",
          "RainbowDelimiterOrange",
          "RainbowDelimiterGreen",
          "RainbowDelimiterViolet",
          "RainbowDelimiterCyan",
        },
      }
      vim.api.nvim_set_hl(0, "RainbowDelimiterRed", { fg = colors.red })
      vim.api.nvim_set_hl(0, "RainbowDelimiterYellow", { fg = colors.yellow })
      vim.api.nvim_set_hl(0, "RainbowDelimiterBlue", { fg = colors.blue })
      vim.api.nvim_set_hl(0, "RainbowDelimiterOrange", { fg = colors.orange })
      vim.api.nvim_set_hl(0, "RainbowDelimiterGreen", { fg = colors.green })
      vim.api.nvim_set_hl(0, "RainbowDelimiterViolet", { fg = colors.purple })
      vim.api.nvim_set_hl(0, "RainbowDelimiterCyan", { fg = colors.cyan })
    end,
  },

  -- Hlchunk - chunk highlighting with arrows and scope-type colors
  -- Using fork with node_type_styles feature and wrapped line fix
  -- PR submitted upstream: https://github.com/shellRaining/hlchunk.nvim/pull/178
  {
    "parkers0405/hlchunk.nvim",
    branch = "main",
    event = "BufReadPost",
    config = function()
      local colors = require("base46").get_theme_tb("base_30")
      require("hlchunk").setup {
        chunk = {
          enable = true,
          use_treesitter = true,
          style = {
            { fg = colors.blue },
            { fg = colors.red },
          },
          chars = {
            horizontal_line = "─",
            vertical_line = "│",
            left_top = "╭",
            left_bottom = "╰",
            left_arrow = "─",
            right_arrow = ">",
          },
          delay = 50,
          duration = 100,
          -- Different colors for different scope types
          node_type_styles = {
            ["^func"] = { fg = colors.blue },
            ["method"] = { fg = colors.blue },
            ["^if"] = { fg = colors.purple },
            ["else"] = { fg = colors.purple },
            ["match"] = { fg = colors.purple },
            ["^for"] = { fg = colors.yellow },
            ["^while"] = { fg = colors.yellow },
            ["do_block"] = { fg = colors.yellow },
            ["try"] = { fg = colors.green },
            ["except"] = { fg = colors.green },
            ["catch"] = { fg = colors.green },
            ["with"] = { fg = colors.green },
            ["class"] = { fg = colors.red },
            ["object"] = { fg = colors.cyan },
            ["table"] = { fg = colors.cyan },
            ["dictionary"] = { fg = colors.cyan },
          },
          exclude_filetypes = {
            NvimTree = true,
            help = true,
            dashboard = true,
            lazy = true,
            mason = true,
            notify = true,
            toggleterm = true,
            TelescopePrompt = true,
          },
        },
        indent = {
          enable = false,
        },
        line_num = {
          enable = false,
        },
        blank = {
          enable = false,
        },
      }
    end,
  },
}
