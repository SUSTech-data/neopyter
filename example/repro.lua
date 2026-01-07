vim.env.LAZY_STDPATH = ".repro"
load(vim.fn.system("curl -s https://raw.githubusercontent.com/folke/lazy.nvim/main/bootstrap.lua"))()

require("lazy.minit").repro({
    spec = {
        {
            "SUSTech-data/neopyter",
            dir = "../",
            dependencies = {
                "nvim-lua/plenary.nvim",
                "nvim-treesitter/nvim-treesitter", -- neopyter don't depend on `nvim-treesitter`, but does depend on treesitter parser of python
                "AbaoFromCUG/websocket.nvim",      -- for mode='direct'
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
    },
})
require("nvim-treesitter").install("python"):wait()
require("nvim-treesitter").install("r"):wait()
