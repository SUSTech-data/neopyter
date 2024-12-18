vim.env.LAZY_STDPATH = ".repro"
load(vim.fn.system("curl -s https://raw.githubusercontent.com/folke/lazy.nvim/main/bootstrap.lua"))()

require("lazy.minit").repro({
    spec = {
        {
            "nvim-treesitter/nvim-treesitter",
            config = function()
                require("nvim-treesitter.configs").setup({
                    auto_install = true,
                })
            end,
        },
        {
            "neovim/nvim-lspconfig",
            config = function()
                local capabilities = require("cmp_nvim_lsp").default_capabilities()
                require("lspconfig").pyright.setup({
                    capabilities = capabilities,
                })
            end,
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
                            maxwidth = 50,
                            ellipsis_char = "...",
                            menu = {
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
            dependencies = {
                "nvim-lua/plenary.nvim",
                "AbaoFromCUG/websocket.nvim",
            },
            ---@type neopyter.Option
            opts = {
                mode = "direct",
                remote_address = "127.0.0.1:9001",
                file_pattern = { "*.ju.*" },
                on_attach = function(buf)
                    -- Keymaps --------------------------------------------
                    local function map(mode, lhs, rhs, desc)
                        vim.keymap.set(mode, lhs, rhs, { desc = desc, buffer = buf })
                    end
                    -- same, recommend the former
                    map("n", "<localleader>nc", "<cmd>Neopyter execute notebook:run-cell<cr>", "run selected")
                    -- map("n", "<C-Enter>", "<cmd>Neopyter run current<cr>", "run selected")

                    -- same, recommend the former
                    map("n", "<localleader>nA", "<cmd>Neopyter execute notebook:run-all-above<cr>", "run all above cell")
                    -- map("n", "<space>X", "<cmd>Neopyter run allAbove<cr>", "run all above cell")

                    -- same, recommend the former, but the latter is silent
                    map("n", "<localleader>nr", "<cmd>Neopyter execute kernelmenu:restart<cr>", "restart kernel")
                    -- map("n", "<space>nt", "<cmd>Neopyter kernel restart<cr>", "restart kernel")

                    map("n", "<localleader>nn", "<cmd>Neopyter execute runmenu:run<cr>", "run selected and select next")
                    map("n", "<localleader>nN", "<cmd>Neopyter execute run-cell-and-insert-below<cr>", "run selected and insert below")

                    map("n", "<localleader>nR", "<cmd>Neopyter execute notebook:restart-run-all<cr>", "restart kernel and run all")
                end,
                highlight = {
                    enable = true,
                    shortsighted = false,
                },
                parser = {
                    -- trim leading/tailing whitespace of cell
                    trim_whitespace = false,
                },
            },
        },
        lazy = false,
    },
})
