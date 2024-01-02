local highlight = require("neopyter.highlight")
local utils = require("neopyter.utils")
local options = require("neopyter.options")
local manager = require("neopyter.manager")

local M = {}

---setup neopyter
---@param opts neopyter.Option
function M.setup(opts)
    options = vim.tbl_deep_extend("force", {}, options, opts)
    manager.create_autocmd()
    highlight.setup(options.highlight)
end

return M
