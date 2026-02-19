local M = {}

local configured = false

local function merged_capabilities()
	local caps = vim.lsp.protocol.make_client_capabilities()
	local ok_blink, blink = pcall(require, "blink.cmp")
	if ok_blink and type(blink.get_lsp_capabilities) == "function" then
		caps = blink.get_lsp_capabilities(caps)
	end
	return caps
end

local function configure_server(name, opts)
	local ok_config = pcall(vim.lsp.config, name, opts)
	if not ok_config then
		return false
	end
	return pcall(vim.lsp.enable, name)
end

local function setup_servers()
	local capabilities = merged_capabilities()

	local common = {
		capabilities = capabilities,
	}

	local servers = {
		lua_ls = {
			settings = {
				Lua = {
					runtime = { version = "LuaJIT" },
					diagnostics = { globals = { "vim" } },
					workspace = { checkThirdParty = false },
				},
			},
		},
		bashls = {},
		jsonls = {},
		yamlls = {},
		html = {},
		cssls = {},
		pyright = {
			settings = {
				python = {
					analysis = {
						typeCheckingMode = "basic",
						autoImportCompletions = true,
					},
				},
			},
		},
		rust_analyzer = {},
		clangd = {},
		nixd = {},
		ts_ls = {},
	}

	for name, server_opts in pairs(servers) do
		local opts = vim.tbl_deep_extend("force", common, server_opts)
		local ok = configure_server(name, opts)

		if not ok and name == "ts_ls" then
			-- Fallback for older lspconfig naming.
			configure_server("tsserver", opts)
		end
	end
end

local function setup_ui()
	vim.diagnostic.config({
		virtual_text = false,
		virtual_lines = false,
		signs = true,
		underline = true,
		severity_sort = true,
		update_in_insert = false,
		float = {
			border = "rounded",
			source = "if_many",
			max_width = 90,
		},
	})

	local group = vim.api.nvim_create_augroup("ghostty_lsp_defaults", { clear = true })
	vim.api.nvim_create_autocmd("LspAttach", {
		group = group,
		callback = function(args)
			local client = vim.lsp.get_client_by_id(args.data.client_id)
			if not client then
				return
			end

			if client:supports_method("textDocument/inlayHint") and vim.lsp.inlay_hint then
				pcall(vim.lsp.inlay_hint.enable, true, { bufnr = args.buf })
			end
		end,
	})
end

function M.setup()
	if configured then
		return
	end
	configured = true

	setup_servers()
	setup_ui()
end

return M
