vim.api.nvim_create_autocmd("BufWritePost", {
  pattern = "*.tsx",
  callback = function()
    os.execute "curl -sS -o /dev/null http://localhost:4001/force-compile"
  end,
})

vim.api.nvim_create_user_command("ForceCompile", function()
  os.execute "curl -sS -o /dev/null http://localhost:4001/force-compile"
end, {})

-- Close the empty starter buffer when opening a real file
vim.api.nvim_create_autocmd("BufReadPost", {
  callback = function()
    local current_buf = vim.api.nvim_get_current_buf()
    local current_bufname = vim.api.nvim_buf_get_name(current_buf)
    
    -- Only proceed if we just opened a real file
    if current_bufname ~= "" and vim.fn.filereadable(current_bufname) == 1 then
      -- Look for empty starter buffers to delete
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if buf ~= current_buf and vim.api.nvim_buf_is_loaded(buf) then
          local bufname = vim.api.nvim_buf_get_name(buf)
          local buftype = vim.api.nvim_buf_get_option(buf, "buftype")
          local filetype = vim.api.nvim_buf_get_option(buf, "filetype")
          
          -- Delete empty buffers (no name) or nvdash/starter buffers
          if (bufname == "" and buftype == "") or filetype == "nvdash" or filetype == "alpha" then
            -- Make sure it's not modified
            if not vim.api.nvim_buf_get_option(buf, "modified") then
              vim.api.nvim_buf_delete(buf, { force = false })
            end
          end
        end
      end
    end
  end,
})
