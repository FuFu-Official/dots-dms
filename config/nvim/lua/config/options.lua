-- LazyVim default options: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua

-- Change the default root directory
vim.g.root_spec = { "lsp", "cwd", { ".git", "lua" } }

vim.o.autoread = true

-- Enable OSC 52 clipboard support for SSH connections
if vim.env.SSH_CONNECTION then
  vim.opt.clipboard = "unnamedplus"

  vim.g.clipboard = {
    name = "OSC 52",
    copy = {
      ["+"] = require("vim.ui.clipboard.osc52").copy("+"),
      ["*"] = require("vim.ui.clipboard.osc52").copy("*"),
    },
    paste = {
      ["+"] = require("vim.ui.clipboard.osc52").paste("+"),
      ["*"] = require("vim.ui.clipboard.osc52").paste("*"),
    },
  }
elseif vim.env.WAYLAND_DISPLAY and vim.fn.executable("wl-copy") == 1 and vim.fn.executable("wl-paste") == 1 then
  -- wl-paste reports an empty selection as an error; treat only that case as empty.
  local function paste(primary)
    return function()
      local cmd = { "wl-paste", "--no-newline" }
      if primary then
        table.insert(cmd, "--primary")
      end
      local result = vim.system(cmd, { text = true, env = { LC_ALL = "C" } }):wait()
      if result.code ~= 0 then
        local err = vim.trim(result.stderr or "")
        if err == "Nothing is copied" then
          return { "" }
        end
        vim.notify("clipboard: error: " .. (err ~= "" and err or tostring(result.code)), vim.log.levels.WARN)
        return 0
      end
      return vim.split(result.stdout or "", "\n", { plain = true })
    end
  end

  vim.g.clipboard = {
    name = "wl-clipboard (empty-safe)",
    copy = {
      ["+"] = { "wl-copy", "--type", "text/plain" },
      ["*"] = { "wl-copy", "--primary", "--type", "text/plain" },
    },
    paste = {
      ["+"] = paste(false),
      ["*"] = paste(true),
    },
    cache_enabled = 1,
  }
end
