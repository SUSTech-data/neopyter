local highlight = require("neopyter.highlight")
local jupyter = require("neopyter.jupyter")
local JupyterLab = require("neopyter.jupyter.jupyterlab")
local utils = require("neopyter.utils")

---@toc

local neopyter = {}

---@text

--- What is Neopyter ?
---
--- # Abstract~
---
--- The bridge between Neovim and jupyter lab, edit in Neovim and preview/run in jupyter lab.
---
---@tag neopyter
---@toc_entry Neopyter's purpose

---@tag neopyter-usage
---@toc_entry Usages
---@class neopyter.Option
---@field remote_address? string
---@field file_pattern? string[]
---@field auto_attach? boolean Automatically attach to the Neopyter server when open file_pattern matched files
---@field auto_connect? boolean # auto connect jupyter lab
---@field mode? "direct"|"proxy"
---@field filename_mapper? fun(ju_path:string):string
---@field on_attach? fun(bufnr:number)
---@field jupyter? neopyter.JupyterOption
---@field highlight? neopyter.HighlightOption
---@field parse_option? neopyter.ParseOption

---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
---@type neopyter.Option
neopyter.config = {
    remote_address = "127.0.0.1:9001",
    file_pattern = { "*.ju.*" },
    filename_mapper = function(ju_path)
        local ipynb_path = ju_path:gsub("%.ju%.%w+", ".ipynb")
        return ipynb_path
    end,

    auto_attach = true,
    auto_connect = true,
    mode = "direct",
    jupyter = {
        auto_activate_file = true,
        -- Always scroll to the current cell.
        scroll = {
            enable = true,
            align = "center",
        },
    },

    use_default_keybindings = true,

    highlight = {
        enable = true,
        -- Dim all cells except the current one
        shortsighted = true,
    },
    parse_option = {
        line_magic = true,
    },
}

---@param config neopyter.Option
function neopyter.setup(config)
    neopyter.config = vim.tbl_deep_extend("force", neopyter.config, config or {})

    if pcall(require, "neoconf") then
        require("neopyter.neoconf").setup()
    end

    jupyter.jupyterlab = JupyterLab:new({
        address = neopyter.config.remote_address,
    })

    if neopyter.config.auto_attach then
        local augroup = vim.api.nvim_create_augroup("neopyter", { clear = true })
        utils.nvim_create_autocmd({ "BufReadPost" }, {
            group = augroup,
            pattern = neopyter.config.file_pattern,
            callback = function()
                vim.api.nvim_del_augroup_by_id(augroup)
                jupyter.jupyterlab:attach()
                if neopyter.config.auto_connect then
                    jupyter.jupyterlab:connect()
                end
            end,
        })
    end

    highlight.setup(neopyter.config.highlight)
end

---@tag neopyter-api
---@toc_entry API
return neopyter
