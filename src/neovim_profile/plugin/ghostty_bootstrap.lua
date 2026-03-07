pcall(function()
	local treesitter = require("configs.treesitter")
	treesitter.ensure_runtimepath()
	treesitter.ensure_tool_path()
end)

pcall(function()
	require("bootstrap").setup()
end)

pcall(function()
	local function setup_tabufline()
		pcall(function()
			require("configs.tabufline").setup()
		end)
	end

	local group = vim.api.nvim_create_augroup("ghostty_tabufline_boot", { clear = true })
	vim.api.nvim_create_autocmd({ "UIEnter", "VimEnter" }, {
		group = group,
		callback = setup_tabufline,
	})

	vim.schedule(setup_tabufline)
end)
