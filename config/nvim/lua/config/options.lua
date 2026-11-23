-- Core settings live here; plugin setup and keymaps live in lua/config/.
-- Keep leaders before plugin loading so every mapping uses the same prefix.
-- Cache compiled Lua modules for faster startup.
vim.loader.enable()
vim.g.mapleader = " "
vim.g.maplocalleader = " "
-- Set this to false if the terminal font has no Nerd Font icons.
vim.g.have_nerd_font = true

-- Show absolute line numbers and relative distances for motions.
vim.o.number = true
vim.o.relativenumber = true
vim.o.mouse = "a" -- Allow mouse navigation and split resizing.
vim.o.showmode = false -- The statusline already shows the current mode.
vim.o.cursorline = true -- Highlight the cursor's line.
vim.o.scrolloff = 10 -- Keep context above and below the cursor.
vim.o.signcolumn = "yes" -- Reserve space so diagnostics do not shift the text.
vim.o.breakindent = true -- Preserve indentation on wrapped lines.
-- Make tabs, trailing spaces, and nonbreaking spaces visible.
vim.o.list = true
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

-- Keep undo history after closing a file.
vim.o.undofile = true
-- Search without case sensitivity unless the pattern includes capitals or \C.
vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.inccommand = "split" -- Preview substitutions as they are typed.
-- Open new splits to the right and below the current window.
vim.o.splitright = true
vim.o.splitbelow = true
vim.o.confirm = true -- Offer to save instead of failing when a buffer is modified.
vim.opt.virtualedit = "block" -- Let block selections extend past the end of a line.
vim.o.updatetime = 250 -- Delay before CursorHold, used for reference highlights.
vim.o.timeoutlen = 300 -- Time to wait for the rest of a mapped key sequence.

-- Defer clipboard discovery until startup has finished.
vim.schedule(function() vim.o.clipboard = "unnamedplus" end)

-- Vimtex
vim.g.tex_flavor = "latex"
vim.g.vimtex_view_method = "zathura"
vim.g.vimtex_compiler_method = "latexmk"
-- Default to XeLaTeX; project-specific engine directives can override this.
vim.g.vimtex_compiler_latexmk_engines = { _ = "-xelatex" }

-- Diagnostics stay visible without changing while typing.
vim.diagnostic.config {
  update_in_insert = false,
  severity_sort = true,
  float = { border = "rounded", source = "if_many" },
  underline = { severity = { min = vim.diagnostic.severity.WARN } },
  virtual_text = true, -- Show diagnostics at the end of the line.
  virtual_lines = false, -- Set to true to show them on separate lines instead.
  jump = {
    -- Open details automatically after diagnostic motions such as [d and ]d.
    on_jump = function(_, bufnr)
      vim.diagnostic.open_float {
        bufnr = bufnr,
        scope = "cursor",
        focus = false,
      }
    end,
  },
}

-- Restore the last cursor position saved in ShaDa when reopening a file.
vim.api.nvim_create_autocmd("BufReadPost", {
  desc = "Restore last cursor position",
  group = vim.api.nvim_create_augroup("config-restore-cursor", { clear = true }),
  callback = function(event)
    if vim.bo[event.buf].buftype ~= "" or vim.tbl_contains({ "gitcommit", "gitrebase" }, vim.bo[event.buf].filetype) then return end

    local mark = vim.api.nvim_buf_get_mark(event.buf, '"')
    if mark[1] > 0 and mark[1] <= vim.api.nvim_buf_line_count(event.buf) then
      vim.api.nvim_win_set_cursor(0, mark)
      vim.cmd "normal! zv"
    end
  end,
})

vim.api.nvim_create_autocmd("TextYankPost", {
  desc = "Highlight yanked text",
  group = vim.api.nvim_create_augroup("config-highlight-yank", { clear = true }),
  callback = function() vim.hl.on_yank() end,
})
