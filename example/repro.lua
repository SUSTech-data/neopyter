vim.env.LAZY_STDPATH = ".repro"
load(vim.fn.system("curl -s https://raw.githubusercontent.com/folke/lazy.nvim/main/bootstrap.lua"))()

require("lazy.minit").repro({
    spec = {
        {
            "SUSTech-data/neopyter",
            priority = 1000,
            lazy = false,
            dir = "../",
            dependencies = {
                "nvim-lua/plenary.nvim",
                "AbaoFromCUG/websocket.nvim", -- for mode='direct'
            },
            ---@type neopyter.Option
            opts = {
                mode = "direct",
                remote_address = "127.0.0.1:9001",
                file_pattern = { "*.ju.*" },
                on_attach = function(bufnr)
                    -- do some buffer keymap
                end,
            },
        },
        {
            "nvim-treesitter/nvim-treesitter",
            branch = "master",
            priority = 1001, -- make sure `nvim-treesitter` is loaded before `neopyter`
            lazy = false,
            config = function()
                require('nvim-treesitter.configs').setup {
                    ensure_installed = { "python", "r", "markdown", "markdown_inline" },
                    sync_install = true,
                    auto_install = true,
                }
            end,

        }, -- neopyter don't depend on `nvim-treesitter`, but does depend on treesitter parser of python
    },
})
