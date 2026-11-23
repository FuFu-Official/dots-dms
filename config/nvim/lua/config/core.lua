-- Formatting ---------------------------------------------------------------
local format_on_save = {}

require("conform").setup {
  notify_on_error = true,
  format_on_save = function(bufnr)
    if format_on_save[vim.bo[bufnr].filetype] then return { timeout_ms = 500 } end
  end,
  -- Prefer external formatters; fall back to LSP when none are available.
  -- Use "never" to disable the LSP fallback.
  default_format_opts = { lsp_format = "fallback" },
  formatters_by_ft = {
    -- Formatters run in sequence. Add stop_after_first = true to use only the first available one.
    c = { "clang_format" },
    cpp = { "clang_format" },
    lua = { "stylua" },
    python = { "black", "isort" },
  },
}

-- Completion and snippets -------------------------------------------------
require("luasnip").setup {}
require("luasnip.loaders.from_vscode").lazy_load() -- require "https://github.com/rafamadriz/friendly-snippets",

require("blink.cmp").setup {
  -- Completion controls belong here: <C-y> accepts, <C-space> opens documentation.
  keymap = {
    preset = "default",
    ["<C-k>"] = { "select_prev", "fallback" },
    ["<C-j>"] = { "select_next", "fallback" },
    ["<C-h>"] = {
      function(cmp) cmp.scroll_documentation_down(4) end,
    },
    ["<C-l>"] = {
      function(cmp) cmp.scroll_documentation_up(4) end,
    },
  },
  -- Use "normal" for a regular Nerd Font instead of Nerd Font Mono.
  appearance = { nerd_font_variant = "mono" },
  completion = {
    -- Set auto_show = true to display documentation after the delay.
    documentation = { auto_show = false, auto_show_delay_ms = 500 },
  },
  sources = { default = { "lsp", "path", "snippets", "buffer" } },
  snippets = { preset = "luasnip" },
  fuzzy = { implementation = "rust" },
  -- Show parameter information while typing a function call.
  signature = { enabled = true },
}

-- Language servers --------------------------------------------------------
-- Fidget displays progress from language servers.
require("fidget").setup {}

-- Enable inlay hints by default; <leader>th toggles them for the current buffer.
vim.lsp.inlay_hint.enable(true)

-- Highlight references while the cursor rests, then clear them on movement.
-- Replacing this buffer's callbacks avoids duplicates when multiple servers attach.
local highlight_group = vim.api.nvim_create_augroup("config-lsp-highlight", { clear = true })
local lsp_group = vim.api.nvim_create_augroup("config-lsp-events", { clear = true })
vim.api.nvim_create_autocmd("LspAttach", {
  group = lsp_group,
  callback = function(event)
    local client = vim.lsp.get_client_by_id(event.data.client_id)
    if not client or not client:supports_method("textDocument/documentHighlight", event.buf) then return end

    vim.api.nvim_clear_autocmds { group = highlight_group, buffer = event.buf }
    vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
      group = highlight_group,
      buffer = event.buf,
      callback = vim.lsp.buf.document_highlight,
    })
    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
      group = highlight_group,
      buffer = event.buf,
      callback = vim.lsp.buf.clear_references,
    })
  end,
})

vim.api.nvim_create_autocmd("LspDetach", {
  group = lsp_group,
  callback = function(event)
    -- Keep highlighting if another attached server can still provide it.
    for _, client in ipairs(vim.lsp.get_clients { bufnr = event.buf, method = "textDocument/documentHighlight" }) do
      if client.id ~= event.data.client_id then return end
    end
    vim.api.nvim_buf_call(event.buf, vim.lsp.buf.clear_references)
    vim.api.nvim_clear_autocmds { group = highlight_group, buffer = event.buf }
  end,
})

-- Add server names and settings here; Mason installs them and Neovim enables them.
-- Server names follow nvim-lspconfig, e.g. gopls, rust_analyzer, or ts_ls.
---@type table<string, vim.lsp.Config>
local servers = {
  clangd = {},
  pyright = {},
  fish_lsp = {},
  stylua = {}, -- StyLua also provides an LSP for Lua formatting.
  lua_ls = {
    on_init = function(client)
      -- Keep formatting with StyLua instead of lua_ls.
      client.server_capabilities.documentFormattingProvider = false

      -- Respect a project's own Lua settings outside the Neovim config directory.
      if client.workspace_folders then
        local path = client.workspace_folders[1].name
        if path ~= vim.fn.stdpath "config" and (vim.uv.fs_stat(path .. "/.luarc.json") or vim.uv.fs_stat(path .. "/.luarc.jsonc")) then return end
      end

      local current_settings = client.config.settings --[[@as lspconfig.settings.lua_ls]]
      client.config.settings.Lua = vim.tbl_deep_extend("force", current_settings.Lua, {
        runtime = {
          version = "LuaJIT",
          path = { "lua/?.lua", "lua/?/init.lua" },
        },
        workspace = {
          checkThirdParty = false,
          -- Include Neovim/plugin APIs. This is convenient but can slow Lua analysis.
          library = vim.api.nvim_get_runtime_file("", true),
        },
      })
    end,
    settings = { Lua = { format = { enable = false } } },
  },
  texlab = {},
}

local formatters = {
  isort = {},
  black = {},
  prettier = {},
  stylua = {},
  clang_format = {},
}
require("conform").formatters = formatters

-- Map Conform names that differ from Mason package names.
local formatter_packages = {
  clang_format = "clang-format",
}

require("mason").setup {}
-- Mason translates server names (lua_ls) to package names (lua-language-server).
-- Enable only the servers above, even if other servers were installed manually.
require("mason-lspconfig").setup { automatic_enable = false }

local tools = vim.tbl_keys(servers)
for name in pairs(formatters) do
  tools[#tools + 1] = formatter_packages[name] or name
end
require("mason-tool-installer").setup { ensure_installed = tools }

for name, config in pairs(servers) do
  vim.lsp.config(name, config)
  vim.lsp.enable(name)
end

-- Treesitter --------------------------------------------------------------
-- Install common parsers up front; other supported languages install on FileType.
local treesitter = require "nvim-treesitter"
local parsers = {
  "bash",
  "c",
  "cpp",
  "python",
  "diff",
  "html",
  "lua",
  "luadoc",
  "markdown",
  "markdown_inline",
  "query",
  "vim",
  "vimdoc",
  -- "latex", use vimtex instead
}
treesitter.install(parsers)

local function attach_parser(bufnr, language)
  -- Installation is asynchronous: the buffer may have closed or changed filetype.
  if not vim.api.nvim_buf_is_valid(bufnr) then return end
  if vim.treesitter.language.get_lang(vim.bo[bufnr].filetype) ~= language then return end

  -- Unknown filetypes may have no parser; keep their normal syntax highlighting.
  local ok, loaded = pcall(vim.treesitter.language.add, language)
  if not ok or not loaded then return end
  vim.treesitter.start(bufnr, language)

  -- Use Treesitter folds; options.lua keeps them open by default.
  -- Keep folds open by default, including the first file and newly opened buffers.
  vim.opt.foldlevel = 99
  vim.opt.foldlevelstart = 99
  vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
  vim.wo.foldmethod = "expr"

  -- Use Treesitter indentation only when an indent query exists for this language.
  if vim.treesitter.query.get(language, "indents") then vim.bo[bufnr].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()" end
end

local available_parsers = treesitter.get_available()
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("config-treesitter", { clear = true }),
  callback = function(event)
    local language = vim.treesitter.language.get_lang(event.match)
    -- Leave LaTeX highlighting and indentation to VimTeX.
    if not language or language == "latex" then return end

    if vim.tbl_contains(treesitter.get_installed "parsers", language) then
      attach_parser(event.buf, language)
    elseif vim.tbl_contains(available_parsers, language) then
      treesitter.install(language):await(function() attach_parser(event.buf, language) end)
    else
      -- Also support parsers provided by another plugin or installed manually.
      attach_parser(event.buf, language)
    end
  end,
})
