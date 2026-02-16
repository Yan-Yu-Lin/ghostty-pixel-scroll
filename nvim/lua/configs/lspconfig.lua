-- ~/.config/nvim/lua/configs/lspconfig.lua
-- Native Neovim LSP (no nvim-lspconfig). Quiet Ruff overlaps, add Pyright, robust attach.

-- Prevent double-loading
if vim.g.custom_lspconfig_loaded then
  return
end
vim.g.custom_lspconfig_loaded = true

-- NVChad helpers/capabilities (swap these for your own if not using NVChad)
local nc = require "nvchad.configs.lspconfig"

-- ---- capabilities ----
local base_caps = vim.lsp.protocol.make_client_capabilities()
-- ensure workspace dynamic registration bits are advertised (ruff cares)
base_caps.workspace = vim.tbl_deep_extend("force", base_caps.workspace or {}, {
  didChangeConfiguration = { dynamicRegistration = true },
  didChangeWatchedFiles = { dynamicRegistration = true },
})

-- merge NVChad caps if present
local merged_caps = vim.tbl_deep_extend("force", base_caps, nc and nc.capabilities or {})

local common = {
  on_attach = nc and nc.on_attach or function() end,
  on_init = nc and nc.on_init or function() end,
  capabilities = merged_caps,
}

-- ---------- utils ----------
local function root_dir(patterns)
  local found = vim.fs.find(patterns, {
    upward = true,
    path = vim.fs.dirname(vim.api.nvim_buf_get_name(0)),
    stop = vim.uv.os_homedir(),
  })[1]
  return found and vim.fs.dirname(found) or vim.fn.getcwd()
end

local function cmd_exists(cmd)
  return vim.fn.executable(cmd) == 1
end

-- Prevent duplicate clients for the same name/root, BUT attach current buffer if client exists
local function start_once(opts)
  local bufnr = vim.api.nvim_get_current_buf()

  if type(opts.root_dir) == "function" then
    opts.root_dir = opts.root_dir()
  end

  -- Reuse existing client and attach to this buffer if needed
  for _, c in pairs(vim.lsp.get_clients { name = opts.name }) do
    if c.config.root_dir == opts.root_dir then
      if not (c.attached_buffers and c.attached_buffers[bufnr]) then
        vim.lsp.buf_attach_client(bufnr, c.id)
      end
      return
    end
  end

  -- Start new client
  if not (opts.cmd and opts.cmd[1] and cmd_exists(opts.cmd[1])) then
    vim.notify(
      ("LSP: missing executable '%s' for %s"):format(tostring(opts.cmd and opts.cmd[1]), opts.name),
      vim.log.levels.WARN
    )
    return
  end

  vim.lsp.start(vim.tbl_deep_extend("force", common, opts))
end

-- Helper to register per-filetype starters
local function ft_start(ft, make_opts)
  vim.api.nvim_create_autocmd("FileType", {
    pattern = ft,
    callback = function()
      start_once(make_opts())
    end,
  })
end

-- ---------- Python: Ruff (lint/format) ----------
ft_start({ "python" }, function()
  -- Resolve absolute path to avoid PATH shenanigans; fall back to "ruff"
  local ruff_bin = vim.fn.exepath "ruff"
  if ruff_bin == "" then
    ruff_bin = "ruff"
  end
  return {
    name = "ruffd",
    cmd = { ruff_bin, "server" }, -- Ruff's built-in LSP
    cmd_env = { RUST_LOG = "error", RUFF_LOG = "error" },
    root_dir = function()
      return root_dir { "pyproject.toml", "ruff.toml", ".git" }
    end,
    init_options = { settings = { configurationPreference = "filesystem" } },
    -- Use UTF-16 to match Pyright (avoids position encoding mismatch warning)
    offset_encoding = "utf-16",
  }
end)

-- ---------- Python: Pyright / BasedPyright ----------
ft_start({ "python" }, function()
  -- Try Pyright, then BasedPyright
  local p = vim.fn.exepath "pyright-langserver"
  if p == "" then
    p = vim.fn.exepath "basedpyright-langserver"
  end
  if p == "" then
    p = "pyright-langserver"
  end -- let start_once warn if missing

  return {
    name = "pyright",
    cmd = { p, "--stdio" },
    root_dir = function()
      return root_dir { "pyproject.toml", "setup.cfg", "setup.py", "requirements.txt", ".git" }
    end,
    capabilities = (function()
      -- keep merged caps but add tagSupport (helps some UIs dedupe)
      local caps = vim.deepcopy(merged_caps)
      caps.textDocument = caps.textDocument or {}
      caps.textDocument.publishDiagnostics = caps.textDocument.publishDiagnostics or {}
      caps.textDocument.publishDiagnostics.tagSupport = { valueSet = { 2 } }
      return caps
    end)(),
    settings = {
      pyright = {
        disableOrganizeImports = true, -- Ruff handles imports
        disableTaggedHints = true, -- trims hint noise
      },
      python = {
        analysis = {
          typeCheckingMode = "basic", -- or "strict"
          autoImportCompletions = true,
          useLibraryCodeForTypes = true,
          -- Reduce overlap with Ruff:
          diagnosticSeverityOverrides = {
            reportUnusedImport = "none",
            reportUnusedVariable = "none",
            reportUnusedClass = "none",
            reportUnusedFunction = "none",
            -- If Docker/Nix hides deps during edit, also mute these (optional):
            reportMissingImports = "none",
            reportMissingModuleSource = "none",
            -- Keep undefined-variable active so real name errors still show:
            -- reportUndefinedVariable = "none",
          },
        },
      },
    },
  }
end)

-- ---------- Nix ----------
ft_start({ "nix" }, function()
  local nixd_bin = vim.fn.exepath "nixd"
  if nixd_bin == "" then
    nixd_bin = "nixd"
  end
  return {
    name = "nixd",
    cmd = { nixd_bin },
    root_dir = function()
      return root_dir { "flake.nix", "shell.nix", "default.nix", ".git" }
    end,
    settings = {
      nixd = {
        nixpkgs = {
          expr = "import <nixpkgs> { }",
        },
        formatting = {
          command = { "nixfmt" }, -- or "alejandra" if you prefer
        },
        options = {
          nixos = {
            expr = '(builtins.getFlake "/etc/nixos").nixosConfigurations.framework16.options',
          },
        },
      },
    },
  }
end)

-- ---------- TypeScript / JavaScript ----------
ft_start({ "typescript", "typescriptreact", "javascript", "javascriptreact" }, function()
  return {
    name = "tsserver",
    cmd = { "typescript-language-server", "--stdio" },
    root_dir = function()
      return root_dir { "package.json", "tsconfig.json", "jsconfig.json", ".git" }
    end,
  }
end)

-- ---------- HTML ----------
ft_start({ "html" }, function()
  return {
    name = "html",
    cmd = { "vscode-html-language-server", "--stdio" },
    root_dir = function()
      return root_dir { "index.html", "package.json", ".git" }
    end,
  }
end)

-- ---------- CSS / SCSS / Less ----------
ft_start({ "css", "scss", "less" }, function()
  return {
    name = "cssls",
    cmd = { "vscode-css-language-server", "--stdio" },
    root_dir = function()
      return root_dir { "package.json", ".git" }
    end,
    settings = {
      css = { validate = true },
      less = { validate = true },
      scss = { validate = true },
    },
  }
end)

-- ---------- Terraform ----------
ft_start({ "terraform", "terraform-vars", "tf" }, function()
  return {
    name = "terraformls",
    cmd = { "terraform-ls", "serve" },
    root_dir = function()
      return root_dir { "main.tf", ".terraform", ".git" }
    end,
  }
end)

-- ---------- OmniSharp (C# / Razor) ----------
ft_start({ "cs", "csharp", "cshtml", "razor" }, function()
  return {
    name = "omnisharp",
    cmd = { "omnisharp", "--languageserver", "--hostPID", tostring(vim.fn.getpid()) },
    root_dir = function()
      return root_dir { "global.json", "*.sln", "*.csproj", ".git" }
    end,
    settings = {
      FormattingOptions = { EnableEditorConfigSupport = true },
      RoslynExtensionsOptions = {
        EnableAnalyzersSupport = true,
        EnableImportCompletion = true,
      },
      Razor = {
        EnableEditorConfigSupport = true,
        FormattingOptions = { EnableEditorConfigSupport = true },
        EnableRazorDiagnostics = true,
      },
    },
  }
end)

-- ---------- Diagnostics UI ----------
-- Disable default virtual text - using tiny-inline-diagnostic.nvim instead
vim.diagnostic.config {
  virtual_text = false,
  virtual_lines = false,
  underline = true,
  signs = true,
  severity_sort = true,
  float = { border = "rounded", max_width = 100, source = "always" },
}

vim.keymap.set("n", "gl", vim.diagnostic.open_float)
