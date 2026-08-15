return {
  {
    "mason-org/mason.nvim",
    -- Add mason bin to Neovim PATH
    init = function()
      local mason_bin = vim.fn.stdpath("data") .. "/mason/bin"
      if not vim.env.PATH:find(mason_bin, 1, true) then
        vim.env.PATH = mason_bin .. ":" .. vim.env.PATH
      end
    end,
    opts = {
      PATH = "prepend",
    },
  },
  {
    "neovim/nvim-lspconfig",
    ---@class PluginLspOpts
    opts = {
      servers = {
        fish_lsp = {},
        bashls = {},
        texlab = {
          settings = {
            texlab = {
              build = {
                executable = "xelatex",
                args = { "-interaction=nonstopmode", "-synctex=1", "%f" },
                forwardSearchAfter = true,
                onSave = true,
              },
              forwardSearch = {
                args = { "--synctex-forward", "%l:1:%f", "%p" },
                executable = "zathura",
              },
            },
          },
        },
        jsonls = {
          settings = {
            json = {
              schemas = {
                { fileMatch = { "*.json", "*.jsonc" }, schema = { allowTrailingCommas = true } },
              },
            },
          },
        },
      },
    },
  },
}
