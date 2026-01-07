local root = vim.fn.fnamemodify(".tests", ":p")

for _, name in ipairs({ "config", "data", "state", "cache" }) do
    vim.env[("XDG_%s_HOME"):format(name:upper())] = vim.fs.joinpath(root, name)
end

local __project_root__ = vim.fs.dirname(vim.fs.dirname(debug.getinfo(1).source:sub(2)))

local function add_dependence(url, name, ...)
    local plugin_path = vim.fn.stdpath("config") --[[@as string]]

    if not vim.fn.isdirectory(plugin_path) then
        vim.fn.mkdir(plugin_path)
    end
    local temp_dir = plugin_path .. "/plugin/" .. name
    if vim.fn.isdirectory(temp_dir) == 0 then
        local out = vim.system({ "git", "clone", url, temp_dir, ... }):wait()
        assert(out.code == 0, "Failed to clone " .. url .. "\n" .. out.stderr)
    end
    vim.opt.rtp:append(temp_dir)
    local after_path = vim.fs.joinpath(temp_dir, "after")
    if vim.fn.isdirectory(after_path) then
        vim.opt.rtp:append(after_path)
    end
end

add_dependence("https://github.com/nvim-lua/plenary.nvim", "plenary.nvim")
add_dependence("https://github.com/nvim-treesitter/nvim-treesitter", "nvim-treesitter", "--branch", "main")
add_dependence("https://github.com/nvim-treesitter/nvim-treesitter-textobjects", "nvim-treesitter-textobjects", "--branch", "main")
add_dependence("https://github.com/AbaoFromCUG/websocket.nvim", "websocket.nvim")
add_dependence("https://github.com/nvim-neotest/nvim-nio", "nvim-nio")
add_dependence("https://github.com/pysan3/pathlib.nvim", "pathlib.nvim")
add_dependence("https://github.com/kdheepak/panvimdoc", "panvimdoc")

vim.opt.rtp:append(__project_root__)
vim.opt.rtp:append(vim.fs.joinpath(__project_root__, "after"))

vim.cmd("runtime plugin/plenary.vim")
require("plenary.busted")

require("nvim-treesitter").setup({})
require("nvim-treesitter").install({ "lua", "python", "markdown" }):wait()
vim.opt.rtp:append(vim.fs.joinpath(vim.fn.stdpath("data"), "site"))
