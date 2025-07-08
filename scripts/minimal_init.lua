local root = vim.fn.fnamemodify(".tests", ":p")

for _, name in ipairs({ "config", "data", "state", "cache" }) do
    vim.env[("XDG_%s_HOME"):format(name:upper())] = root .. "/" .. name
end
vim.opt.packpath:append(vim.fs.joinpath(vim.fn.stdpath("data"), "site"))

local __project_root__ = vim.fs.dirname(vim.fs.dirname(debug.getinfo(1).source:sub(2)))

vim.pack.add {
    "https://github.com/nvim-lua/plenary.nvim",
    "https://github.com/AbaoFromCUG/websocket.nvim",
    "https://github.com/nvim-neotest/nvim-nio",
    "https://github.com/pysan3/pathlib.nvim",
    "https://github.com/kdheepak/panvimdoc",
    { src = "https://github.com/nvim-treesitter/nvim-treesitter",             version = "main" },
    { src = "https://github.com/nvim-treesitter/nvim-treesitter-textobjects", version = "main" },
}


vim.opt.rtp:append(__project_root__)
vim.opt.rtp:append(vim.fs.joinpath(__project_root__, "after"))

vim.cmd("runtime plugin/plenary.vim")
require("plenary.busted")
require("nvim-treesitter").setup({})

require 'nvim-treesitter'.install { "lua", "python", "markdown" }:wait(300000)

