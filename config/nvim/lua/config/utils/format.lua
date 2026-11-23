local function format_buffer() require("conform").format { async = true } end

local function format_and_save()
  -- Finish formatting before writing, so the saved file contains the edits.
  require("conform").format({ async = false, timeout_ms = 3000 }, function(err)
    if err then return end
    vim.cmd "write"
  end)
end

local function format_save_and_quit()
  require("conform").format({ async = false, timeout_ms = 3000 }, function(err)
    if err then return end
    vim.cmd "write"
    vim.cmd "quitall"
  end)
end

-- Format files under :pwd, respecting .gitignore/.ignore and using CLI formatters.
local project_format_running = false
local function format_project()
  if project_format_running then
    vim.notify("Project formatting is already running", vim.log.levels.WARN)
    return
  end
  local ok, conform = pcall(require, "conform")
  if not ok or vim.fn.executable "rg" == 0 then
    vim.notify("Project formatting requires conform.nvim and ripgrep", vim.log.levels.ERROR)
    return
  end

  local root = vim.fn.getcwd()
  project_format_running = true
  local started, scan_error = pcall(
    vim.system,
    { "rg", "--files", "--hidden", "--null", "--glob", "!.git" },
    { cwd = root },
    vim.schedule_wrap(function(result)
      if result.code ~= 0 and result.code ~= 1 then
        project_format_running = false
        vim.notify("Cannot list project files: " .. (result.stderr or ""), vim.log.levels.ERROR)
        return
      end

      local files = vim.split(result.stdout or "", "\0", { plain = true, trimempty = true })
      table.sort(files)
      local counts = { formatted = 0, unchanged = 0, skipped = 0, failed = 0 }
      local errors = {}
      local index = 0
      local next_file
      next_file = function()
        index = index + 1
        local relative_path = files[index]
        if not relative_path then
          project_format_running = false
          local message = string.format(
            "Project format (%s): %d formatted, %d unchanged, %d skipped, %d failed",
            root,
            counts.formatted,
            counts.unchanged,
            counts.skipped,
            counts.failed
          )
          if #errors > 0 then message = message .. "\n" .. table.concat(errors, "\n") end
          vim.notify(message, counts.failed > 0 and vim.log.levels.WARN or vim.log.levels.INFO)
          return
        end

        local path = vim.fs.joinpath(root, relative_path)
        local bufnr
        local created = false
        local finished = false
        local function finish(status, err)
          if finished then return end
          finished = true
          counts[status] = counts[status] + 1
          if err then errors[#errors + 1] = relative_path .. ": " .. tostring(err) end
          if created and bufnr and vim.api.nvim_buf_is_valid(bufnr) then
            if vim.bo[bufnr].modified or #vim.fn.win_findbuf(bufnr) > 0 then
              -- Keep unsaved results and buffers opened by the user during formatting.
              vim.bo[bufnr].buflisted = true
            else
              pcall(vim.api.nvim_buf_delete, bufnr, { force = false })
            end
          end
          vim.schedule(next_file)
        end

        local success, err = pcall(function()
          bufnr = vim.fn.bufnr(path)
          if bufnr ~= -1 and vim.bo[bufnr].modified then
            finish "skipped"
            return
          end
          local filetype = vim.filetype.match { filename = path }
          if not filetype then
            finish "skipped"
            return
          end
          created = bufnr == -1
          if created then bufnr = vim.fn.bufadd(path) end
          vim.fn.bufload(bufnr)
          if vim.bo[bufnr].filetype == "" then vim.bo[bufnr].filetype = filetype end
          if vim.bo[bufnr].modified or vim.bo[bufnr].readonly or not vim.bo[bufnr].modifiable or vim.bo[bufnr].buftype ~= "" then
            finish "skipped"
            return
          end
          if #conform.list_formatters(bufnr) == 0 then
            finish "skipped"
            return
          end

          local line_count = vim.api.nvim_buf_line_count(bufnr)
          local last_line = vim.api.nvim_buf_get_lines(bufnr, -2, -1, true)[1]
          conform.format({
            bufnr = bufnr,
            async = true,
            lsp_format = "never",
            quiet = true,
            -- Always format the whole file, even if the user enters Visual mode mid-run.
            range = { start = { 1, 0 }, ["end"] = { line_count, #last_line } },
          }, function(format_error, did_edit)
            if format_error then
              finish("failed", format_error)
            elseif not did_edit then
              finish "unchanged"
            else
              local written, write_error = pcall(vim.api.nvim_buf_call, bufnr, function() vim.cmd "silent noautocmd write" end)
              finish(written and "formatted" or "failed", not written and write_error or nil)
            end
          end)
        end)
        if not success then finish("failed", err) end
      end

      vim.notify(string.format("Formatting %d project file(s) under %s", #files, root))
      next_file()
    end)
  )
  if not started then
    project_format_running = false
    vim.notify("Cannot list project files: " .. tostring(scan_error), vim.log.levels.ERROR)
  end
end

return {
  format_buffer = format_buffer,
  format_and_save = format_and_save,
  format_save_and_quit = format_save_and_quit,
  format_project = format_project,
}
