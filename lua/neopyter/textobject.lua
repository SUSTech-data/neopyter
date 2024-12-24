local utils = require("neopyter.utils")
local M = {}

---@class neopyter.TextObjectOption
---@field enable boolean
---@field queries ("cellseparator"|"cellcontent"|"cell")[] # default cellseparator

---@nodoc
---setup textobject
function M.setup()
    local opts = require("neopyter").config.textobject
    ---@cast opts -nil
    if not opts.enable then
        return
    end
    vim.iter(opts.queries):each(function(name)
        require("neopyter.treesitter").load_query("textobjects", "python", name)
    end)
end

return M
