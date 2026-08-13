return {
  {
    "ellisonleao/gruvbox.nvim",
    priority = 1000,
    opts = {
      -- transparent_mode = true,
    },
  },
  {
    "catppuccin/nvim",
    priority = 1000,
    opts = {
      flavour = "mocha",
      -- transparent_background = true,
      auto_integrations = true,
    },
  },
  {
    "rose-pine/neovim",
    name = "rose-pine",
    priority = 1000,
    opts = {
      variant = "moon",
      styles = {
        -- transparency = true,
      },
    },
  },
  {
    "AvengeMedia/base46",
    lazy = true,
    opts = {},
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "dms",
    },
  },
  {
    "xiyaowong/transparent.nvim",
    opts = {
      extra_groups = {
        "NormalFloat",
        "FloatBorder",
      },
    },
    config = function(_, opts)
      require("transparent").setup(opts)
      require("transparent").clear_prefix("gitsigns")
      vim.cmd("TransparentEnable")
    end,
  },
}
