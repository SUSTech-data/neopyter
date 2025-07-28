local root = vim.fn.fnamemodify(".repro-cmp", ":p")

for _, name in ipairs({ "config", "data", "state", "cache" }) do
    vim.env[("XDG_%s_HOME"):format(name:upper())] = root .. "/" .. name
end
vim.opt.packpath:append(vim.fs.joinpath(vim.fn.stdpath("data"), "site"))

local __project_root__ = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(debug.getinfo(1).source:sub(2))))

vim.pack.add {
    "https://github.com/nvim-lua/plenary.nvim",
    "https://github.com/AbaoFromCUG/websocket.nvim",

    "https://github.com/mason-org/mason.nvim",
    'https://github.com/neovim/nvim-lspconfig',
    { src = "https://github.com/nvim-treesitter/nvim-treesitter", version = "main" },

    'https://github.com/hrsh7th/cmp-nvim-lsp',
    'https://github.com/hrsh7th/cmp-buffer',
    'https://github.com/hrsh7th/cmp-path',
    'https://github.com/hrsh7th/cmp-cmdline',
    'https://github.com/hrsh7th/nvim-cmp',
    "https://github.com/onsails/lspkind.nvim",



    "https://github.com/folke/neoconf.nvim",
    "https://github.com/EdenEast/nightfox.nvim",

}

vim.api.nvim_create_autocmd('BufReadPre', {
    callback = function()
        vim.bo.filetype = "python"
        vim.treesitter.start(0, "python")
    end,
})


vim.opt.rtp:append(__project_root__)
vim.opt.rtp:append(vim.fs.joinpath(__project_root__, "after"))

require("mason").setup({})
require("neoconf").setup({})
require("nvim-treesitter").setup({
    install_dir = vim.fn.stdpath('data') .. '/site'
})
require 'nvim-treesitter'.install { "lua", "python", "markdown" }:wait(300000)

vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"

require("mason").setup()

local lspkind = require("lspkind")
local cmp     = require("cmp")
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
vim.cmd([[colorscheme nightfox]])
vim.cmd([[MasonInstall pyright]])

vim.lsp.enable("pyright")

local capabilities = require("cmp_nvim_lsp").default_capabilities()

vim.lsp.config("*", {
    capabilities = capabilities,
})

require("neopyter").setup({
    highlight = {
        enable = true,
        mode = "separator"
    },
})
