local Path = require("plenary.path")

local M = {}

local __filepath__ = debug.getinfo(1).source:sub(2)

--- match cell separator
---@param match table<integer, TSNode[]>
---@param pattern integer
---@param source integer|string
---@param predicate any[]
---@param metadata table
function M.match_cellseparator(match, pattern, source, predicate, metadata)
    print(match)
    print(pattern)
end

function M.make_range_include_whitespace() end

function M.setup()
    vim.treesitter.query.add_predicate("match-cellseparator?", M.match_cellseparator, { force = true, all = true })
    vim.treesitter.query.add_directive("make-range-include-whitespace!", M.make_range_include_whitespace, { force = true, all = true })
end

function M.load_query(query)
    ---@type Path
    local res_path = Path:new(__filepath__):parent():parent():parent():joinpath("res")
    ---@type Path
    local file = Path:new(res_path:joinpath("queries/python"):joinpath(query .. ".scm"))
    local cache_path = Path:new(vim.fn.stdpath("cache")):joinpath("neopyter")

    local query_path = cache_path:joinpath(query)
    local target_path = query_path:joinpath(Path:new(tostring(file)):make_relative(tostring(res_path)))

    vim.fn.mkdir(tostring(target_path:parent()), "p")
    vim.uv.fs_copyfile(tostring(file), tostring(target_path))
    vim.opt.rtp:prepend(tostring(query_path))
end

return M
