-- LazyVim default autocmds: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua

vim.api.nvim_create_user_command("W", "w !sudo tee % > /dev/null", {})

-- Format every supported file below the current project root.
local function format_project()
  local ok, conform = pcall(require, "conform")
  if not ok then
    vim.notify("conform.nvim is not available", vim.log.levels.ERROR)
    return
  end

  local root = LazyVim.root()
  local files = {}
  local ignored = {
    [".git"] = true,
    [".direnv"] = true,
    [".cache"] = true,
    [".tox"] = true,
    [".venv"] = true,
    ["coverage"] = true,
    ["node_modules"] = true,
    ["target"] = true,
    ["dist"] = true,
    ["build"] = true,
    ["vendor"] = true,
  }

  local function scan(directory)
    local handle = vim.uv.fs_scandir(directory)
    if not handle then
      return
    end

    while true do
      local name, kind = vim.uv.fs_scandir_next(handle)
      if not name then
        break
      end

      local path = directory .. "/" .. name
      if kind == "directory" and not ignored[name] then
        scan(path)
      elseif kind == "file" then
        files[#files + 1] = path
      end
    end
  end

  scan(root)

  local formatted = 0
  local skipped = 0
  for _, path in ipairs(files) do
    local filetype = vim.filetype.match({ filename = path })
    if filetype then
      local existing_bufnr = vim.fn.bufnr(path)
      local bufnr = vim.fn.bufadd(path)
      vim.fn.bufload(bufnr)

      if #conform.list_formatters(bufnr) > 0 then
        local changed = vim.api.nvim_buf_get_changedtick(bufnr)
        local success = pcall(conform.format, {
          bufnr = bufnr,
          lsp_format = "fallback",
          quiet = false,
          timeout_ms = 10000,
        })

        if success and vim.api.nvim_buf_get_changedtick(bufnr) ~= changed then
          vim.api.nvim_buf_call(bufnr, function()
            vim.cmd("silent noautocmd write")
          end)
          formatted = formatted + 1
        else
          skipped = skipped + 1
        end
      else
        skipped = skipped + 1
      end

      if existing_bufnr == -1 then
        vim.api.nvim_buf_delete(bufnr, { force = true })
      end
    else
      skipped = skipped + 1
    end
  end

  vim.notify(string.format("Formatted %d file(s), skipped %d", formatted, skipped))
end

vim.api.nvim_create_user_command("FormatProject", format_project, {
  desc = "Format all supported files below the project root",
})
