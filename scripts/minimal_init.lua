local root = vim.fn.fnamemodify("/tmp/nvim-fake-home", ":p")

for _, name in ipairs({ "config", "data", "state", "cache" }) do
    vim.env[("XDG_%s_HOME"):format(name:upper())] = root .. "/" .. name
end

local __project_root__ = vim.fs.dirname(vim.fs.dirname(debug.getinfo(1).source:sub(2)))

local function add_dependence(url, name)
    local temp_dir = "/tmp/" .. name
    if vim.fn.isdirectory(temp_dir) == 0 then
        vim.fn.system({ "git", "clone", url, temp_dir })
    end
    vim.opt.rtp:append(temp_dir)
    local after_path = vim.fs.joinpath(temp_dir, "after")
    if vim.fn.isdirectory(after_path) then
        vim.opt.rtp:append(after_path)
    end
end

add_dependence("https://github.com/nvim-lua/plenary.nvim", "plenary.nvim")
add_dependence("https://github.com/nvim-treesitter/nvim-treesitter", "nvim-treesitter")
add_dependence("https://github.com/nvim-treesitter/nvim-treesitter-textobjects", "nvim-treesitter-textobjects")
add_dependence("https://github.com/echasnovski/mini.nvim", "mini.nvim")
add_dependence("https://github.com/AbaoFromCUG/websocket.nvim", "websocket.nvim")
--
vim.opt.rtp:append(__project_root__)
vim.opt.rtp:append(vim.fs.joinpath(__project_root__, "after"))

vim.cmd("runtime plugin/plenary.vim")
require("plenary.busted")

require("nvim-treesitter.configs").setup({
    indent = { enable = true },
    highlight = { enable = true },
    sync_install = true,
    auto_install = true,
    ensure_installed = {
        "python",
    },
    ignore_install = {},
    modules = {},
    textobjects = {
        select = {
            enable = true,

            -- Automatically jump forward to textobj, similar to targets.vim
            lookahead = true,

            keymaps = {
                -- You can use the capture groups defined in textobjects.scm
                ["af"] = "@function.outer",
                ["if"] = "@function.inner",
                ["ac"] = "@class.outer",
                -- You can optionally set descriptions to the mappings (used in the desc parameter of
                -- nvim_buf_set_keymap) which plugins like which-key display
                ["ic"] = { query = "@class.inner", desc = "Select inner part of a class region" },
                -- You can also use captures from other query groups like `locals.scm`
                ["as"] = { query = "@scope", query_group = "locals", desc = "Select language scope" },
            },
            -- You can choose the select mode (default is charwise 'v')
            --
            -- Can also be a function which gets passed a table with the keys
            -- * query_string: eg '@function.inner'
            -- * method: eg 'v' or 'o'
            -- and should return the mode ('v', 'V', or '<c-v>') or a table
            -- mapping query_strings to modes.
            selection_modes = {
                ["@parameter.outer"] = "v", -- charwise
                ["@function.outer"] = "V", -- linewise
                ["@class.outer"] = "<c-v>", -- blockwise
            },
            -- If you set this to `true` (default is `false`) then any textobject is
            -- extended to include preceding or succeeding whitespace. Succeeding
            -- whitespace has priority in order to act similarly to eg the built-in
            -- `ap`.
            --
            -- Can also be a function which gets passed a table with the keys
            -- * query_string: eg '@function.inner'
            -- * selection_mode: eg 'v'
            -- and should return true or false
            include_surrounding_whitespace = true,
        },
    },
})

require("nvim-treesitter")
