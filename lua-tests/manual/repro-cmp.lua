vim.env.LAZY_STDPATH = ".repro"
load(vim.fn.system("curl -s https://raw.githubusercontent.com/folke/lazy.nvim/main/bootstrap.lua"))()

vim.opt.number = true

local has_words_before = function()
    unpack = unpack or table.unpack
    local line, col = unpack(vim.api.nvim_win_get_cursor(0))
    return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match("%s") == nil
end

require("lazy.minit").repro({
    spec = {

        {
            "folke/neoconf.nvim",
            config = true,
            keys = {
                { "<leader>,,", "<cmd>Neoconf local<cr>", desc = "local settings" },
            },
            lazy = false,
        },
        {
            "nvim-treesitter/nvim-treesitter",
            config = function()
                require("nvim-treesitter.configs").setup({
                    sync_install = true,
                    auto_install = true,
                    ensure_installed = {
                        "python",
                    },
                })
            end,
            lazy = false,
        },
        {
            "neovim/nvim-lspconfig",

            dependencies = {
                "neoconf.nvim",
            },
            config = function()
                local capabilities = require("cmp_nvim_lsp").default_capabilities()
                require("lspconfig").pyright.setup({
                    capabilities = capabilities,
                })
            end,
            lazy = false,
        },
        {
            "hrsh7th/nvim-cmp",
            dependencies = {
                "hrsh7th/cmp-nvim-lsp",
                "hrsh7th/cmp-buffer",
                "hrsh7th/cmp-path",
                "hrsh7th/cmp-cmdline",
                "onsails/lspkind.nvim",
            },
            config = function()
                local lspkind = require("lspkind")
                local cmp = require("cmp")
                cmp.setup({
                    snippet = {
                        expand = function(args)
                            vim.snippet.expand(args.body) -- For native neovim snippets (Neovim v0.10+)
                        end,
                    },

                    sources = cmp.config.sources({
                        { name = "nvim_lsp" },
                        { name = "path" },
                        { name = "neopyter" },
                    }, {
                        { name = "buffer" },
                    }),
                    formatting = {
                        format = lspkind.cmp_format({
                            mode = "symbol_text",
                            menu = {
                                buffer = "[Buf]",
                                nvim_lsp = "[LSP]",
                                nvim_lua = "[Lua]",
                                neopyter = "[Neopyter]",
                            },
                            symbol_map = {
                                -- specific complete item kind icon
                                ["Magic"] = "🪄",
                                ["Path"] = "📁",
                                ["Dict key"] = "🔑",
                                ["Instance"] = "󱃻",
                                ["Statement"] = "󱇯",
                            },
                        }),
                    },
                })
            end,
            lazy = false,
        },
        {
            "SUSTech-data/neopyter",
            dev = true,
            dependencies = {
                "nvim-lua/plenary.nvim",
                "AbaoFromCUG/websocket.nvim",
            },
            ---@type neopyter.Option
            opts = {
                mode = "direct",
                remote_address = "127.0.0.1:9001",
                file_pattern = { "*.ju.*" },
                highlight = {
                    enable = true,
                    mode = "zen",
                },
                parser = {
                    -- trim leading/tailing whitespace of cell
                    trim_whitespace = false,
                },
            },
        },
        lazy = false,
    },

    dev = {
        path = "..",
        fallback = true,
    },
})
