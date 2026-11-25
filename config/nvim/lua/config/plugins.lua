-- Register build hooks before vim.pack.add so first-time installs work too.
local function run_build(name, command, cwd)
  local result = vim.system(command, { cwd = cwd }):wait()
  if result.code == 0 then return end

  local output = result.stderr or ""
  if output == "" then output = result.stdout or "" end
  if output == "" then output = "No output from build command." end
  vim.notify(("Build failed for %s:\n%s"):format(name, output), vim.log.levels.ERROR)
end

vim.api.nvim_create_autocmd("PackChanged", {
  group = vim.api.nvim_create_augroup("config-plugin-builds", { clear = true }),
  callback = function(event)
    local data = event.data
    if data.kind ~= "install" and data.kind ~= "update" then return end

    local name = data.spec.name
    if name == "telescope-fzf-native.nvim" and vim.fn.executable "make" == 1 then
      run_build(name, { "make" }, data.path)
    elseif name == "LuaSnip" and vim.fn.has "win32" ~= 1 and vim.fn.executable "make" == 1 then
      run_build(name, { "make", "install_jsregexp" }, data.path)
    elseif name == "nvim-treesitter" then
      if not data.active then vim.cmd.packadd "nvim-treesitter" end
      vim.cmd "TSUpdate"
    end
  end,
})

-- Keep the plugin inventory here; language-specific setup is in coding.lua.
---@type (string | vim.pack.Spec)[]
local plugins = {
  -- Shared dependencies.
  "https://github.com/nvim-lua/plenary.nvim",
  "https://github.com/MunifTanjim/nui.nvim",

  -- Colorschemes
  "https://github.com/ellisonleao/gruvbox.nvim",
  "https://github.com/catppuccin/nvim",
  "https://github.com/folke/tokyonight.nvim",
  "https://github.com/rose-pine/neovim",
  "https://github.com/duxlabs-dev/base46",

  -- Interface, navigation, and editing helpers.
  "https://github.com/mikesmithgh/kitty-scrollback.nvim",
  { src = "https://github.com/nvim-neo-tree/neo-tree.nvim", version = vim.version.range "*" },
  "https://github.com/hedyhli/outline.nvim",
  "https://github.com/lukas-reineke/indent-blankline.nvim",
  "https://github.com/NMAC427/guess-indent.nvim",
  "https://github.com/folke/todo-comments.nvim",
  "https://github.com/lewis6991/gitsigns.nvim",
  "https://github.com/folke/which-key.nvim",
  "https://github.com/nvim-mini/mini.nvim",
  "https://github.com/nvim-telescope/telescope.nvim",
  "https://github.com/nvim-telescope/telescope-ui-select.nvim",
  "https://github.com/nvim-telescope/telescope-fzf-native.nvim", -- require make cmd

  -- Language servers, formatters, completion, and syntax parsing.
  "https://github.com/j-hui/fidget.nvim",
  "https://github.com/neovim/nvim-lspconfig",
  "https://github.com/mason-org/mason.nvim",
  "https://github.com/mason-org/mason-lspconfig.nvim",
  "https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim",
  "https://github.com/stevearc/conform.nvim",
  "https://github.com/lervag/vimtex",
  "https://github.com/L3MON4D3/LuaSnip",
  "https://github.com/rafamadriz/friendly-snippets",

  { src = "https://github.com/saghen/blink.cmp", version = vim.version.range "*" },
  { src = "https://github.com/nvim-treesitter/nvim-treesitter", version = "main" },
  { src = "https://github.com/nvim-treesitter/nvim-treesitter-textobjects", version = "main" },
}
vim.pack.add(plugins)

require("kitty-scrollback").setup()

local keymaps = require "config.keymaps"

-- Icons must be ready before plugins look for nvim-web-devicons.
if vim.g.have_nerd_font then
  require("mini.icons").setup()
  MiniIcons.mock_nvim_web_devicons()
end

---@diagnostic disable-next-line: missing-fields
require("tokyonight").setup { transparent = true }
require("gruvbox").setup { transparent_mode = true }
require("catppuccin").setup { flavour = "mocha", transparent_background = true, auto_integrations = true }
require("rose-pine").setup { variant = "moon", styles = { transparency = true } }
require("base46").setup {
  transparency = true,
  -- Fix for mini statusline and tabline
  hl_override = {
    -- MiniStatuslineModeNormal = { fg = "black", bg = "blue", bold = true },
    -- MiniStatuslineModeInsert = { fg = "black", bg = "green", bold = true },
    -- MiniStatuslineModeVisual = { fg = "black", bg = "purple", bold = true },
    -- MiniStatuslineModeReplace = { fg = "black", bg = "red", bold = true },
    -- MiniStatuslineModeCommand = { fg = "black", bg = "yellow", bold = true },
    -- MiniStatuslineModeOther = { fg = "black", bg = "teal", bold = true },
    -- MiniStatuslineDevinfo = { fg = "white", bg = "lightbg" },
    -- MiniStatuslineFilename = { fg = "white", bg = "NONE" },
    -- MiniStatuslineFileinfo = { fg = "white", bg = "lightbg" },
    -- MiniStatuslineInactive = { fg = "grey_fg", bg = "NONE" },
    MiniTablineFill = { link = "Normal" },
    MiniTablineTrunc = { link = "MiniTablineHidden" },
  },
}
vim.cmd.colorscheme "dms"

require("neo-tree").setup {}
require("ibl").setup {}
require("guess-indent").setup {}
require("todo-comments").setup { signs = false }
require("gitsigns").setup { on_attach = keymaps.git_attach }
require("outline").setup {}

require("which-key").setup {
  delay = 0,
  icons = { mappings = vim.g.have_nerd_font },
  replace = {
    desc = {
      -- Match paired parentheses explicitly so <Plug> labels lose both ends.
      { "^<Plug>%((.*)%)$", "%1" },
      { "^<Plug>", "" },
      { "^%+", "" },
      { "<[cC]md>", "" },
      { "<[cC][rR]>", "" },
      { "<[sS]ilent>", "" },
      { "^lua%s+", "" },
      { "^call%s+", "" },
      { "^:%s*", "" },
    },
  },
  spec = keymaps.groups,
}

-- Plugin-managed text objects and surround keys are also defined in keymaps.lua.
require("mini.ai").setup {
  mappings = keymaps.textobjects,
  custom_textobjects = keymaps.textobject_specs(),
  n_lines = 500,
}
require("mini.surround").setup { mappings = keymaps.surround }
-- require("mini.statusline").setup { use_icons = vim.g.have_nerd_font }
require("config.utils.statusline").setup()
require("mini.tabline").setup { use_icons = vim.g.have_nerd_font }

-- Telescope prompt controls stay here; editor shortcuts are centralized.
require("telescope").setup {
  defaults = {
    mappings = {
      i = {
        ["<C-j>"] = require("telescope.actions").move_selection_next,
        ["<C-k>"] = require("telescope.actions").move_selection_previous,
      },
    },
  },
  extensions = {
    ["ui-select"] = { require("telescope.themes").get_dropdown() },
  },
}
pcall(require("telescope").load_extension, "fzf")
pcall(require("telescope").load_extension, "ui-select")
