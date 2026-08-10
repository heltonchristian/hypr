vim.opt.termguicolors = true

vim.opt.number = true

vim.cmd('syntax enable') 
vim.api.nvim_set_hl(0, 'Normal', { bg = '#2a2a2a' })

vim.api.nvim_set_hl(0, 'NonText', { bg = '#2a2a2a' })
vim.api.nvim_set_hl(0, 'NormalFloat', { bg = '#2a2a2a' })
