local ts = require("neopyter.treesitter")

---@class neopyter.ParserOption
---@field trim_whitespace? boolean Whether trim leading/trailing whitespace, but keep 1 line each cell at least, default false
---@field python? neopyter.PercentParserOption

---@class neopyter.ICell
---@field start_row number include, 0-based
---@field end_row number include, 0-based
---@field no_separator? boolean # this cell without separator, like first cell
---@field type string
---@field title? string
---@field metadata? table<string, any>

---@class neopyter.INotebook
---@field metadata? table
---@field cells neopyter.ICell[]

---@class neopyter.Parser
---@field trim_whitespace boolean
---@field separator_query vim.treesitter.Query
---@field separator_capture string
local Parser = {}
Parser.__index = Parser

function Parser:new(o)
    o = o or {} -- create object if user does not provide one
    o.separator_capture = "cellseparator"
    setmetatable(o, self)
    return o --[[@as neopyter.Parser]]
end

---get iteration of separator
---@param source number|string|string[]  buffer or source code
---@param row number? #0-based, cursor position default
---@param col number? #0-based, cursor position default
---@param direct "forward"|"backward" # default forward
---@return Iter
function Parser:iter_separator(source, row, col, direct)
    if row == nil then
        row = vim.fn.line(".") - 1
    end
    if col == nil then
        col = vim.fn.col(".") - 1
    end
    direct = direct or "forward"
end

---get iteration of cell
---@param source number|string|string[]  buffer or source code
---@param start_row integer # zero default
---@param end_row integer # full default
---@return Iter # ICell source
function Parser:iter_cell(source, start_row, end_row) end

---get each cell range
---@param source number|string|string[]  buffer or source code
---@return neopyter.INotebook
function Parser:parse_notebook(source) end

---parse cell source
---@param source number|string|string[]  buffer or source code
---@param cell neopyter.ICell
function Parser:parse_source(source, cell) end

return Parser
