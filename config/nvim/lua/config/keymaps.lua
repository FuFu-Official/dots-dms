-- All editor shortcuts live here, including buffer-local Git/LSP bindings.
-- Completion and picker prompt controls stay with their plugins.
local M = {}
local builtin = require "telescope.builtin"
local gitsigns = require "gitsigns"
local format = require "config.utils.format"

-- Keep longer actions above the table so key assignments remain easy to scan.
local function find_config() builtin.find_files { cwd = vim.fn.stdpath "config", follow = true } end

local function pack_update() vim.pack.update() end

local function grep_buffer()
  builtin.current_buffer_fuzzy_find(require("telescope.themes").get_dropdown {
    winblend = 10,
    previewer = false,
  })
end

local function grep_open_files()
  builtin.live_grep {
    grep_open_files = true,
    prompt_title = "Live Grep in Open Files",
  }
end

local function find_git_hunks()
  gitsigns.setqflist("all", { open = false }, function(err)
    if err then
      vim.notify(err, vim.log.levels.ERROR)
      return
    end
    builtin.quickfix { prompt_title = "Git Diff Hunks" }
  end)
end

local function delete_buffer() require("mini.bufremove").delete() end

local function delete_other_buffers()
  local current = vim.api.nvim_get_current_buf()
  for _, buf in ipairs(vim.fn.getbufinfo { buflisted = 1 }) do
    if buf.bufnr ~= current then require("mini.bufremove").delete(buf.bufnr) end
  end
end

local function delete_invisible_buffers()
  for _, buf in ipairs(vim.fn.getbufinfo { buflisted = 1 }) do
    if #vim.fn.win_findbuf(buf.bufnr) == 0 then require("mini.bufremove").delete(buf.bufnr) end
  end
end

local function next_git_change()
  if vim.wo.diff then
    vim.cmd.normal { "]c", bang = true }
  else
    gitsigns.nav_hunk "next"
  end
end

local function previous_git_change()
  if vim.wo.diff then
    vim.cmd.normal { "[c", bang = true }
  else
    gitsigns.nav_hunk "prev"
  end
end

local function blame_line() gitsigns.blame_line { full = true } end
local function diff_previous_commit() gitsigns.diffthis "~" end
local function repository_changes() gitsigns.setqflist "all" end
local function reset_selection() gitsigns.reset_hunk { vim.fn.line ".", vim.fn.line "v" } end
local function stage_selection() gitsigns.stage_hunk { vim.fn.line ".", vim.fn.line "v" } end

local function toggle_line_wrap() vim.wo.wrap = not vim.wo.wrap end

local function toggle_inlay_hints()
  -- Restrict the toggle to this buffer instead of changing every LSP buffer.
  local bufnr = vim.api.nvim_get_current_buf()
  vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = bufnr }, { bufnr = bufnr })
end

-- Treesitter motions support counts and normal/visual/operator-pending modes.
local function textobject_jump(method, captures)
  return function() require("nvim-treesitter-textobjects.move")[method](captures, "textobjects") end
end

local block_captures = { "@block.outer", "@conditional.outer", "@loop.outer" }

-- Columns: key, mode, scope, action, description.
-- Scopes: global = every buffer; textobject = filetype buffers; git/lsp/inlay = attached buffers.
-- Sort by key, ignoring case; put lowercase before uppercase variants.
-- To add a shortcut, add one row. Use a mode list when the action is shared.
local mappings = {
  { "jk", "i", "global", "<Esc>", "Exit insert mode" },
  { "<C-h>", "n", "global", "<C-w><C-h>", "Focus left window" },
  { "<C-j>", "n", "global", "<C-w><C-j>", "Focus lower window" },
  { "<C-k>", "n", "global", "<C-w><C-k>", "Focus upper window" },
  { "<C-l>", "n", "global", "<C-w><C-l>", "Focus right window" },
  { "<C-Up>", "n", "global", "<Cmd>resize +2<CR>", "Increase window height" },
  { "<C-Down>", "n", "global", "<Cmd>resize -2<CR>", "Decrease window height" },
  { "<C-Left>", "n", "global", "<Cmd>vertical resize -2<CR>", "Decrease window width" },
  { "<C-Right>", "n", "global", "<Cmd>vertical resize +2<CR>", "Increase window width" },
  { "<Esc>", "n", "global", "<Cmd>nohlsearch<CR>", "Clear search highlights" },
  { "<Esc><Esc>", "t", "global", "<C-\\><C-n>", "Exit terminal mode" },
  { "<leader>x", "n", "global", vim.diagnostic.setloclist, "open diagnostic list" },
  { "<leader>e", "n", "global", "<cmd>Neotree toggle<cr>", "neo-tree" },
  { "<leader>o", "n", "global", "<Cmd>Outline<CR>", "outline" },
  -- Buffers
  { "<S-h>", "n", "global", "<Cmd>bprevious<CR>", "Previous buffer" },
  { "<S-l>", "n", "global", "<Cmd>bnext<CR>", "Next buffer" },
  { "<leader>bb", "n", "global", "<Cmd>buffer #<CR>", "switch to alternate buffer" },
  { "<leader>bd", "n", "global", delete_buffer, "delete buffer" },
  { "<leader>bD", "n", "global", "<Cmd>bdelete<CR>", "delete buffer and window" },
  { "<leader>bi", "n", "global", delete_invisible_buffers, "delete invisible buffers" },
  { "<leader>bo", "n", "global", delete_other_buffers, "delete other buffers" },
  -- Find
  { "<leader>f,", "n", "global", grep_open_files, "grep in open files" },
  { "<leader>f/", "n", "global", grep_buffer, "grep in current buffer" },
  { "<leader>fb", "n", "global", builtin.buffers, "buffers" },
  { "<leader>fc", "n", "global", builtin.commands, "commands" },
  { "<leader>fd", "n", "global", builtin.git_status, "git diff files" },
  { "<leader>fe", "n", "global", builtin.resume, "resume last search" },
  { "<leader>ff", "n", "global", builtin.find_files, "files" },
  { "<leader>fg", "n", "global", builtin.live_grep, "grep in project" },
  { "<leader>fh", "n", "global", builtin.help_tags, "help tags" },
  { "<leader>fj", "n", "global", builtin.jumplist, "jumps" },
  { "<leader>fk", "n", "global", builtin.keymaps, "keymaps" },
  { "<leader>fn", "n", "global", find_config, "neovim configs" },
  { "<leader>fo", "n", "global", "<Cmd>TodoTelescope<CR>", "TODO symbols" },
  { "<leader>fq", "n", "global", builtin.diagnostics, "diagnostics" },
  { "<leader>fr", "n", "global", builtin.oldfiles, "recent files" },
  { "<leader>ft", "n", "global", builtin.builtin, "telescope selections" },
  { "<leader>fu", "n", "global", find_git_hunks, "git diff hunks" },
  { "<leader>fw", { "n", "v" }, "global", builtin.grep_string, "grep by current word / selection" },
  -- Git
  { "<leader>hb", "n", "git", blame_line, "blame line" },
  { "<leader>hd", "n", "git", gitsigns.diffthis, "diff against index" },
  { "<leader>hD", "n", "git", diff_previous_commit, "diff against previous commit" },
  { "<leader>hp", "n", "git", gitsigns.preview_hunk_inline, "preview hunk inline" },
  { "<leader>hq", "n", "git", gitsigns.setqflist, "file changes to quickfix" },
  { "<leader>hQ", "n", "git", repository_changes, "repository changes to quickfix" },
  { "<leader>hr", "n", "git", gitsigns.reset_hunk, "reset hunk to index" },
  { "<leader>hr", "v", "git", reset_selection, "reset selected lines" },
  { "<leader>hs", "n", "git", gitsigns.stage_hunk, "toggle hunk staging" },
  { "<leader>hs", "v", "git", stage_selection, "toggle selection staging" },
  -- Toggle
  { "<leader>tb", "n", "git", gitsigns.toggle_current_line_blame, "inline Git blame" },
  { "<leader>th", "n", "inlay", toggle_inlay_hints, "LSP inlay hints" },
  { "<leader>tl", "n", "global", toggle_line_wrap, "line wrap" },
  { "<leader>tw", "n", "git", gitsigns.toggle_word_diff, "Git word diff" },
  -- Utils
  { "<leader>uF", { "n", "v" }, "global", format.format_buffer, "format buffer only" },
  { "<leader>uQ", { "n", "v" }, "global", format.format_save_and_quit, "format, save and quit all" },
  { "<leader>uu", { "n", "v" }, "global", format.format_and_save, "format and save" },
  { "<leader>uS", { "n", "v" }, "global", "<Cmd>write<CR>", "save only" },
  { "<leader>uA", "n", "global", format.format_project, "format project (cwd)" },
  { "leader>upu", "n", "global", pack_update, "update plugins (vim.pack)" },
  -- LSP navigation uses Telescope; <C-t> returns after a definition jump.
  { "grO", "n", "lsp", builtin.lsp_document_symbols, "LSP: document symbols" },
  { "gra", { "n", "x" }, "lsp", vim.lsp.buf.code_action, "LSP: code actions" },
  { "grd", "n", "lsp", builtin.lsp_definitions, "LSP: definitions" },
  { "grD", "n", "lsp", vim.lsp.buf.declaration, "LSP: declaration" },
  { "gri", "n", "lsp", builtin.lsp_implementations, "LSP: implementations" },
  { "grn", "n", "lsp", vim.lsp.buf.rename, "LSP: rename symbol" },
  { "grr", "n", "lsp", builtin.lsp_references, "LSP: references" },
  { "grt", "n", "lsp", builtin.lsp_type_definitions, "LSP: type definitions" },
  { "grW", "n", "lsp", builtin.lsp_dynamic_workspace_symbols, "LSP: workspace symbols" },
  -- Textobject motions: keep [a/]a for the argument list and [c/]c for Git.
  { "[,", { "n", "x", "o" }, "textobject", textobject_jump("goto_previous_start", "@parameter.inner"), "Previous parameter" },
  { "],", { "n", "x", "o" }, "textobject", textobject_jump("goto_next_start", "@parameter.inner"), "Next parameter" },
  { "[m", { "n", "x", "o" }, "textobject", textobject_jump("goto_previous_start", "@function.outer"), "Previous function start" },
  { "]m", { "n", "x", "o" }, "textobject", textobject_jump("goto_next_start", "@function.outer"), "Next function start" },
  { "[M", { "n", "x", "o" }, "textobject", textobject_jump("goto_previous_end", "@function.outer"), "Previous function end" },
  { "]M", { "n", "x", "o" }, "textobject", textobject_jump("goto_next_end", "@function.outer"), "Next function end" },
  { "[[", { "n", "x", "o" }, "textobject", textobject_jump("goto_previous_start", "@class.outer"), "Previous class start" },
  { "]]", { "n", "x", "o" }, "textobject", textobject_jump("goto_next_start", "@class.outer"), "Next class start" },
  { "[]", { "n", "x", "o" }, "textobject", textobject_jump("goto_previous_end", "@class.outer"), "Previous class end" },
  { "][", { "n", "x", "o" }, "textobject", textobject_jump("goto_next_end", "@class.outer"), "Next class end" },
  { "[o", { "n", "x", "o" }, "textobject", textobject_jump("goto_previous_start", block_captures), "Previous block start" },
  { "]o", { "n", "x", "o" }, "textobject", textobject_jump("goto_next_start", block_captures), "Next block start" },
  { "[O", { "n", "x", "o" }, "textobject", textobject_jump("goto_previous_end", block_captures), "Previous block end" },
  { "]O", { "n", "x", "o" }, "textobject", textobject_jump("goto_next_end", block_captures), "Next block end" },
  { "[c", "n", "git", previous_git_change, "Git: jump to previous change" },
  { "]c", "n", "git", next_git_change, "Git: jump to next change" },
  { "ih", { "o", "x" }, "git", gitsigns.select_hunk, "Git hunk text object" },
}

-- Mini manages expression mappings and operator behavior itself.
-- Keep its key choices here too; an empty string disables a mapping.
-- Entries are ordered by their assigned keys, matching the table above.
M.textobjects = {
  around = "a", -- Around a text object, including delimiters.
  around_next = "aN", -- Keep Neovim's an/in node selection and bracket objects.
  around_last = "aL", -- Uppercase also avoids Neovim's newer al/il objects.
  goto_left = "g[", -- Move to the left edge of a text object.
  goto_right = "g]", -- Move to the right edge of a text object.
  inside = "i", -- Inside a text object, excluding delimiters.
  inside_next = "iN", -- Inside the next matching text object.
  inside_last = "iL", -- Inside the previous matching text object.
}

-- Add functions (m), classes (c), blocks, and buffers; arguments use Mini's built-in spec.
function M.textobject_specs()
  local ai = require "mini.ai"
  return {
    o = ai.gen_spec.treesitter {
      a = block_captures,
      i = { "@block.inner", "@conditional.inner", "@loop.inner" },
    },
    m = ai.gen_spec.treesitter { a = "@function.outer", i = "@function.inner" },
    c = ai.gen_spec.treesitter { a = "@class.outer", i = "@class.inner" },
    g = require("mini.extra").gen_ai_spec.buffer(),
  }
end

-- Surroundings include quotes, brackets, tags, and function calls.
M.surround = {
  add = "sa",
  delete = "sd",
  find = "sf", -- Find the surrounding to the right.
  find_left = "sF", -- Find the surrounding to the left.
  highlight = "sh",
  replace = "sr",
  suffix_last = "l", -- Append to an action to target the previous surrounding.
  suffix_next = "n", -- Append to an action to target the next surrounding.
}

-- Keep which-key labels beside the prefixes they describe.
M.groups = {
  { "<leader>b", group = "Buffers", mode = "n" },
  { "<leader>f", group = "Find", mode = { "n", "v" } },
  { "<leader>h", group = "Git", mode = { "n", "v" } },
  { "<leader>t", group = "Toggle", mode = { "n", "v" } },
  { "<leader>u", group = "Utils", mode = { "n", "v" } },
  { "gr", group = "LSP actions", mode = { "n", "x" } },
}

-- Describe both direct objects and next/previous variants in operator/visual mode.
local textobject_labels = {
  a = "argument",
  c = "class",
  m = "function definition",
  g = "entire buffer",
  o = "block / conditional / loop",
}
for _, name in ipairs { "around", "inside", "around_next", "inside_next", "around_last", "inside_last" } do
  local prefix = M.textobjects[name]
  M.groups[#M.groups + 1] = { prefix, group = name:gsub("_", " "), mode = { "o", "x" } }
  for id, description in pairs(textobject_labels) do
    M.groups[#M.groups + 1] = { prefix .. id, desc = description, mode = { "o", "x" } }
  end
end

local function apply(scope, bufnr)
  for _, mapping in ipairs(mappings) do
    local key, mode, target, action, description = unpack(mapping)
    if target == scope then vim.keymap.set(mode, key, action, { buffer = bufnr, desc = description, silent = true }) end
  end
end

-- Called by Gitsigns only after it attaches to a tracked file.
function M.git_attach(bufnr) apply("git", bufnr) end

function M.setup()
  apply "global"
  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("config-textobject-keymaps", { clear = true }),
    -- Override ftplugin-local method/section motions with Treesitter motions.
    callback = function(event) apply("textobject", event.buf) end,
  })
  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("config-lsp-keymaps", { clear = true }),
    callback = function(event)
      apply("lsp", event.buf)
      local client = vim.lsp.get_client_by_id(event.data.client_id)
      if client and client:supports_method("textDocument/inlayHint", event.buf) then apply("inlay", event.buf) end
    end,
  })
end

return M
