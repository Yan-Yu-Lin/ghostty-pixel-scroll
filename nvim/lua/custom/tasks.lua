local M = {}

M.move_completed_task = function()
  local cursor_pos = vim.api.nvim_win_get_cursor(0) -- Get the current cursor position
  local current_line = vim.api.nvim_get_current_line()

  -- Check if the current line contains a completed task `[x]`
  if current_line:match "|.-%[x%].-|" then
    -- Delete the current line
    vim.api.nvim_buf_set_lines(0, cursor_pos[1] - 1, cursor_pos[1], false, {})

    -- Get all lines in the buffer
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local completed_index = nil

    -- Find the "## Completed Tasks" section
    for i, line in ipairs(lines) do
      if line:match "## Completed Tasks" then
        completed_index = i
        break
      end
    end

    -- If "## Completed Tasks" section doesn't exist, create it
    if not completed_index then
      vim.api.nvim_buf_set_lines(0, -1, -1, false, {
        "",
        "## Completed Tasks",
        "",
        "| Feature                | Description                                  | Status   |",
        "| ---------------------- | -------------------------------------------- | -------- |",
      })
      completed_index = #lines + 1
    end

    -- Append the completed task to the "## Completed Tasks" section
    vim.api.nvim_buf_set_lines(0, completed_index + 2, completed_index + 2, false, { current_line })
  end
end

return M
