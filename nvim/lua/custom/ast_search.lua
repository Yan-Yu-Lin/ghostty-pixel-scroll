-- Smart code pattern search using ast-grep (project-wide, live results)
local M = {}

-- Get git root or current directory
local function get_project_root()
  local handle = io.popen("git rev-parse --show-toplevel 2>&1")
  if not handle then
    return vim.fn.getcwd()
  end
  local result = handle:read("*a")
  handle:close()

  if result:match("fatal") or result == "" then
    return vim.fn.getcwd()
  end

  return result:gsub("\n", "")
end

-- Query translation: natural language → ast-grep patterns
local function translate_query(query)
  local patterns = {}
  local lower = query:lower()

  -- Firestore/collection patterns
  if lower:match("firestore") or lower:match("collection") then
    table.insert(patterns, "$VAR.firestore().collection($NAME)")
    table.insert(patterns, "$VAR.collection($NAME)")
    table.insert(patterns, "firestore().collection($NAME)")
  end

  -- Firebase auth patterns
  if lower:match("auth") then
    table.insert(patterns, "firebase.auth()")
    table.insert(patterns, "$VAR.auth()")
    table.insert(patterns, "authenticate($$$)")
  end

  -- Database get/fetch patterns
  if lower:match("get") or lower:match("fetch") then
    table.insert(patterns, "$VAR.get($TARGET)")
    table.insert(patterns, "await $VAR.get($TARGET)")
    table.insert(patterns, "$DB.fetch($TARGET)")
  end

  -- If no specific patterns matched, create generic patterns
  if #patterns == 0 then
    -- Try to use the query as a pattern
    table.insert(patterns, query)
  end

  return patterns
end

-- Live search with results appearing as you type (like live_grep)
function M.live_pattern_search()
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local make_entry = require("telescope.make_entry")

  local project_root = get_project_root()

  pickers
    .new({}, {
      prompt_title = "🔍 Smart Pattern Search (type to search)",
      finder = finders.new_async_job({
        command_generator = function(prompt)
          if not prompt or prompt == "" then
            return nil
          end

          -- Translate query to patterns
          local patterns = translate_query(prompt)

          -- Build command that outputs in vimgrep format: file:line:col:text
          local cmds = {}
          for _, pattern in ipairs(patterns) do
            table.insert(
              cmds,
              string.format(
                "ast-grep -p %s --json | jq -r '.[] | \"\\(.file):\\(.range.start.line + 1):\\(.range.start.column + 1):\\(.lines)\"'",
                vim.fn.shellescape(pattern)
              )
            )
          end

          -- Return command array
          return { 
            "sh", "-c", 
            "cd " .. vim.fn.shellescape(project_root) .. " && (" .. table.concat(cmds, " ; ") .. ") 2>/dev/null" 
          }
        end,
        entry_maker = make_entry.gen_from_vimgrep(),
        cwd = project_root,
      }),
      sorter = conf.generic_sorter({}),
      previewer = conf.grep_previewer({}),
    })
    :find()
end

-- Alternative: Prompt-based search (not live, but more reliable)
function M.smart_search()
  local project_root = get_project_root()

  vim.ui.input({
    prompt = "🔍 Smart Pattern Search: ",
  }, function(query)
    if not query or query == "" then
      return
    end

    vim.notify("Searching for: " .. query, vim.log.levels.INFO)

    -- Translate to patterns
    local patterns = translate_query(query)

    -- Collect all results
    local all_results = {}
    for _, pattern in ipairs(patterns) do
      local cmd = string.format(
        "cd %s && ast-grep -p %s --json 2>/dev/null",
        vim.fn.shellescape(project_root),
        vim.fn.shellescape(pattern)
      )

      local handle = io.popen(cmd)
      if handle then
        local output = handle:read("*a")
        handle:close()

        local ok, parsed = pcall(vim.fn.json_decode, output)
        if ok and parsed and type(parsed) == "table" then
          for _, match in ipairs(parsed) do
            if match.range and match.range.start and match.file then
              table.insert(all_results, {
                filename = match.file,
                lnum = match.range.start.line + 1,
                col = match.range.start.column + 1,
                text = match.lines or match.text or "",
              })
            end
          end
        end
      end
    end

    if #all_results == 0 then
      vim.notify("No results found for: " .. query, vim.log.levels.WARN)
      return
    end

    -- Show in Telescope
    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local conf = require("telescope.config").values
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")

    pickers
      .new({}, {
        prompt_title = string.format("🔍 Pattern: %s (%d matches)", query, #all_results),
        finder = finders.new_table({
          results = all_results,
          entry_maker = function(entry)
            return {
              value = entry,
              display = string.format(
                "%s:%d:%d: %s",
                entry.filename,
                entry.lnum,
                entry.col,
                entry.text:gsub("^%s+", ""):sub(1, 100)
              ),
              ordinal = entry.filename .. " " .. entry.text,
              filename = entry.filename,
              lnum = entry.lnum,
              col = entry.col,
            }
          end,
        }),
        sorter = conf.generic_sorter({}),
        previewer = conf.grep_previewer({}),
        attach_mappings = function(prompt_bufnr)
          actions.select_default:replace(function()
            local selection = action_state.get_selected_entry()
            if not selection then
              return
            end
            actions.close(prompt_bufnr)
            vim.cmd("edit " .. selection.filename)
            vim.api.nvim_win_set_cursor(0, { selection.lnum, selection.col })
            vim.cmd("normal! zz")
          end)
          return true
        end,
      })
      :find()

    vim.notify(string.format("Found %d matches", #all_results), vim.log.levels.INFO)
  end)
end

-- Quick pattern: Find all collection calls
function M.find_collections()
  local project_root = get_project_root()
  local pattern = "$VAR.collection($NAME)"

  local cmd = string.format(
    "cd %s && ast-grep -p %s --json 2>/dev/null",
    vim.fn.shellescape(project_root),
    vim.fn.shellescape(pattern)
  )

  local handle = io.popen(cmd)
  if not handle then
    vim.notify("Failed to execute ast-grep", vim.log.levels.ERROR)
    return
  end

  local output = handle:read("*a")
  handle:close()

  local ok, parsed = pcall(vim.fn.json_decode, output)
  if not ok or not parsed or #parsed == 0 then
    vim.notify("No collection calls found in project", vim.log.levels.WARN)
    return
  end

  -- Convert to results
  local results = {}
  for _, match in ipairs(parsed) do
    if match.range and match.range.start and match.file then
      table.insert(results, {
        filename = match.file,
        lnum = match.range.start.line + 1,
        col = match.range.start.column + 1,
        text = match.text or "",
      })
    end
  end

  -- Show in Telescope
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  pickers
    .new({}, {
      prompt_title = string.format("📚 Collection Calls (%d found)", #results),
      finder = finders.new_table({
        results = results,
        entry_maker = function(entry)
          return {
            value = entry,
            display = string.format(
              "%s:%d:%d: %s",
              entry.filename,
              entry.lnum,
              entry.col,
              entry.text:gsub("^%s+", ""):sub(1, 100)
            ),
            ordinal = entry.filename .. " " .. entry.text,
            filename = entry.filename,
            lnum = entry.lnum,
            col = entry.col,
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      previewer = conf.grep_previewer({}),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          if not selection then
            return
          end
          actions.close(prompt_bufnr)
          vim.cmd("edit " .. selection.filename)
          vim.api.nvim_win_set_cursor(0, { selection.lnum, selection.col })
          vim.cmd("normal! zz")
        end)
        return true
      end,
    })
    :find()
end

-- Quick pattern: Find all auth patterns
function M.find_auth_patterns()
  local project_root = get_project_root()
  local patterns = { "firebase.auth()", "$VAR.auth()", "authenticate($$$)" }

  local all_results = {}
  for _, pattern in ipairs(patterns) do
    local cmd = string.format(
      "cd %s && ast-grep -p %s --json 2>/dev/null",
      vim.fn.shellescape(project_root),
      vim.fn.shellescape(pattern)
    )

    local handle = io.popen(cmd)
    if handle then
      local output = handle:read("*a")
      handle:close()

      local ok, parsed = pcall(vim.fn.json_decode, output)
      if ok and parsed and type(parsed) == "table" then
        for _, match in ipairs(parsed) do
          if match.range and match.range.start and match.file then
            table.insert(all_results, {
              filename = match.file,
              lnum = match.range.start.line + 1,
              col = match.range.start.column + 1,
              text = match.text or "",
            })
          end
        end
      end
    end
  end

  if #all_results == 0 then
    vim.notify("No auth patterns found in project", vim.log.levels.WARN)
    return
  end

  -- Show in Telescope
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  pickers
    .new({}, {
      prompt_title = string.format("🔐 Auth Patterns (%d found)", #all_results),
      finder = finders.new_table({
        results = all_results,
        entry_maker = function(entry)
          return {
            value = entry,
            display = string.format(
              "%s:%d:%d: %s",
              entry.filename,
              entry.lnum,
              entry.col,
              entry.text:gsub("^%s+", ""):sub(1, 100)
            ),
            ordinal = entry.filename .. " " .. entry.text,
            filename = entry.filename,
            lnum = entry.lnum,
            col = entry.col,
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      previewer = conf.grep_previewer({}),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          if not selection then
            return
          end
          actions.close(prompt_bufnr)
          vim.cmd("edit " .. selection.filename)
          vim.api.nvim_win_set_cursor(0, { selection.lnum, selection.col })
          vim.cmd("normal! zz")
        end)
        return true
      end,
    })
    :find()
end

return M
