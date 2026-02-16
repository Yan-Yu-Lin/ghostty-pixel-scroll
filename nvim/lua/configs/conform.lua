local options = {
  formatters_by_ft = {
    lua = { "stylua" },
    python = { "ruff_format", "isort" },
    javascript = { "prettier" },
    typescript = { "prettier" },
    javascriptreact = { "prettier" },
    typescriptreact = { "prettier" },
    css = { "prettier" },
    html = { "prettier" },
    json = { "prettier" },
    yaml = { "prettier" },
    markdown = { "prettier" },
    graphql = { "prettier" },
    go = { "gofmt" },
    rust = { "rustfmt" },
    cs = { "csharpier" },
    cshtml = { "csharpier" },
    nix = { "nixfmt" },
  },

  format_on_save = {
    timeout_ms = 200000,
    lsp_fallback = true,
  },
}

require("conform").setup(options)
