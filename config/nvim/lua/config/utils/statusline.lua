local M = {}

local modes = {
  i = "INSERT",
  R = "REPLACE",
  v = "VISUAL",
  V = "V-LINE",
  ["\22"] = "V-BLOCK",
  s = "SELECT",
  S = "S-LINE",
  ["\19"] = "S-BLOCK",
  c = "COMMAND",
  r = "PROMPT",
  ["!"] = "SHELL",
  t = "TERMINAL",
}

function M.render()
  local win = vim.g.statusline_winid or vim.api.nvim_get_current_win()
  local left = ""
  if win == vim.api.nvim_get_current_win() then
    local mode = vim.api.nvim_get_mode().mode
    local label = mode:sub(1, 2) == "no" and "OPERATOR" or modes[mode:sub(1, 1)]
    if label then left = " " .. label .. " " end
  end

  local filetype = vim.bo[vim.api.nvim_win_get_buf(win)].filetype
  local right = filetype
  if filetype ~= "" and vim.g.have_nerd_font then
    local icon = require("mini.icons").get("filetype", filetype)
    right = icon .. " " .. filetype
  end
  if right ~= "" then right = " " .. right:gsub("%%", "%%%%") .. " " end
  return left .. "%=" .. right
end

function M.setup()
  vim.o.laststatus = 2
  vim.o.statusline = "%!v:lua.require'config.utils.statusline'.render()"
  vim.api.nvim_create_autocmd("ModeChanged", {
    group = vim.api.nvim_create_augroup("config-statusline", { clear = true }),
    callback = function() vim.cmd.redrawstatus() end,
  })
end

return M
