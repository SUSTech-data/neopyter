local function add_dependence(url, name)
    local temp_dir = "/tmp/" .. name
    if vim.fn.isdirectory(temp_dir) == 0 then
        vim.fn.system({ "git", "clone", url, temp_dir })
    end
    vim.opt.rtp:append(temp_dir)
end

add_dependence("https://github.com/nvim-lua/plenary.nvim", "plenary.nvim")
add_dependence("https://github.com/nvim-treesitter/nvim-treesitter", "nvim-treesitter")
add_dependence("https://github.com/echasnovski/mini.nvim", "mini.nvim")

vim.opt.rtp:append(".")
vim.cmd("runtime plugin/plenary.vim")
require("plenary.busted")
