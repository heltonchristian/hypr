vim.opt.number = true
vim.opt.linespace = 0
vim.g.neovide_scale_factor = 1.0
vim.g.neovide_text_gamma = 0.0
vim.g.neovide_text_contrast = 0.5

vim.g.neovide_padding_top = 0
vim.g.neovide_padding_bottom = 0
vim.g.neovide_padding_right = 0
vim.g.neovide_padding_left = 0

vim.o.guifont = "Fira Code:h11"

-- Helper function for transparency formatting
local alpha = function()
  return string.format("%x", math.floor(255 * vim.g.transparency or 0.1))
end

-- Garantir transparência total
vim.g.neovide_transparency = 1.0  -- Transparência total
vim.g.transparency = 1.0  -- Transparência global
vim.g.neovide_background_color = "rgba(0,0,0,0)"  -- Sem cor de fundo, totalmente transparente

-- Remover qualquer cor de fundo definida pelo Neovide
vim.g.neovide_title_background_color = "rgba(0,0,0,0)"  -- Transparente no título também
vim.g.neovide_title_text_color = "pink"  -- Cor do texto no título
vim.g.neovide_window_blurred = false

--- Animações
vim.g.neovide_cursor_vfx_mode = "torpedo"

if vim.g.neovide then
  vim.keymap.set('n', '<D-s>', ':w<CR>') -- Save
  vim.keymap.set('v', '<D-c>', '"+y') -- Copy
  vim.keymap.set('n', '<D-v>', '"+P') -- Paste normal mode
  vim.keymap.set('v', '<D-v>', '"+P') -- Paste visual mode
  vim.keymap.set('c', '<D-v>', '<C-R>+') -- Paste command mode
  vim.keymap.set('i', '<D-v>', '<ESC>l"+Pli') -- Paste insert mode
end

-- Allow clipboard copy paste in neovim
vim.api.nvim_set_keymap('', '<D-v>', '+p<CR>', { noremap = true, silent = true})
vim.api.nvim_set_keymap('!', '<D-v>', '<C-R>+', { noremap = true, silent = true})
vim.api.nvim_set_keymap('t', '<D-v>', '<C-R>+', { noremap = true, silent = true})
vim.api.nvim_set_keymap('v', '<D-v>', '<C-R>+', { noremap = true, silent = true})
