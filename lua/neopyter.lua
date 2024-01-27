local highlight = require("neopyter.highlight")
local jupyter = require("neopyter.jupyter")
local JupyterLab = require("neopyter.jupyter.jupyterlab")
local utils = require("neopyter.utils")

---@class neopyter.Option
---@field remote_address string
---@field file_pattern string[]
---@field auto_attach boolean
---@field rpc_client
---| "'async'" # AsyncRpcClient, default
---| "'block'" # BlockRpcClient
---@field filename_mapper fun(ju_path:string):string
---@field jupyter neopyter.JupyterOption
---@field highlight neopyter.HighlightOption
---@field parse_option neopyter.ParseOption

local M = {}

---@type neopyter.Option
M.config = {
    remote_address = "127.0.0.1:9001",
    file_pattern = { "*.ju.*" },
    filename_mapper = function(ju_path)
        local ipynb_path = ju_path:gsub("%.ju%.%w+", ".ipynb")
        return ipynb_path
    end,

    --  Automatically attach to the Neopyter server when open file_pattern matched files
    auto_attach = true,
    rpc_client = "async",
    jupyter = {
        auto_activate_file = true,
        -- Always scroll to the current cell.
        scroll = {
            enable = true,
            mode = "always", -- "always" or "invisible"
            step = 0.5,
        },
    },

    use_default_keybindings = true,

    highlight = {
        enable = true,
        -- Dim all cells except the current one
        shortsighted = false,
    },
    parse_option = {
        line_magic = true,
    },
}

---setup neopyter
---@param config neopyter.Option
function M.setup(config)
    M.config = vim.tbl_deep_extend("force", M.config, config or {})

    jupyter.jupyterlab = JupyterLab:new({
        address = M.config.remote_address,
    })

    if M.config.auto_attach then
        local augroup = vim.api.nvim_create_augroup("neopyter", { clear = true })
        utils.nvim_create_autocmd({ "BufReadPost" }, {
            group = augroup,
            pattern = M.config.file_pattern,
            callback = function()
                if not jupyter.jupyterlab:is_connecting() then
                    jupyter.jupyterlab:attach()
                end
            end,
        })
    end
    highlight.setup(M.config.highlight)

    local status, cmp = pcall(require, "cmp")
    if status then
        cmp.register_source("neopyter", require("neopyter.cmp"))
        return
    end
end

return M
