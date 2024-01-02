---@class neopyter.Option
---@field remote_address string
---@field file_pattern string[]
---@field auto_attach boolean
---@field filename_mapper fun(ju_path:string):string
---@field jupyter neopyter.JupyterOption
---@field highlight neopyter.HighlightOption

---@class neopyter.JupyterOption
---@field auto_new_file boolean
---@field auto_open_file boolean
---@field auto_activate_file boolean

---@class neopyter.OptionModule
---@field opts neopyter.Option
local M = {
    remote_address = "127.0.0.1:8888",
    file_pattern = { "*.ju.*" },
    filename_mapper = function(ju_path)
        local ipynb_path = ju_path:gsub("%.ju%.%w+", ".ipynb")
        return ipynb_path
    end,

    --  Automatically attach to the Noepyter server when open file_pattern matched files
    auto_attach = true,
    jupyter = {
        -- Automatically new corresponding ipynb file on Jupyter Lab
        auto_new_file = true,
        -- Automatically open corresponding ipynb file on Jupyter Lab
        auto_open_file = true,
        -- Automatically focus corresponding ipynb file on Jupyter Lab
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

return M
