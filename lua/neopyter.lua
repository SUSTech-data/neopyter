local highlight = require("neopyter.highlight")
local utils = require("neopyter.utils")
local manager = require("neopyter.manager")

---@class neopyter.Option
---@field remote_address string
---@field file_pattern string[]
---@field auto_attach boolean
---@field filename_mapper fun(ju_path:string):string
---@field jupyter neopyter.JupyterOption
---@field highlight neopyter.HighlightOption

local M = {}

---@type neopyter.Option
M.config = {
    remote_address = "127.0.0.1:9001",
    file_pattern = { "*.ju.*" },
    filename_mapper = function(ju_path)
        local ipynb_path = ju_path:gsub("%.ju%.%w+", ".ipynb")
        return ipynb_path
    end,

    --  Automatically attach to the Noepyter server when open file_pattern matched files
    auto_attach = true,
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
}

---setup neopyter
---@param config neopyter.Option
function M.setup(config)
    M.config = vim.tbl_deep_extend("force", M.config, config or {})
    manager.setup(M.config)
    highlight.setup(M.config.highlight)
end

return M
