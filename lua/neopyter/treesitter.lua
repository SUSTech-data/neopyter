local M = {}

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

return M
