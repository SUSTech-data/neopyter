local Path = require("plenary.path")

local M = {}

local __filepath__ = debug.getinfo(1).source:sub(2)

---@class neopyter.TSOption
---@field enable boolean
---@field patterns table<"cellseparator", string[]>

local cell_type_shorthands = {
    md = "markdown",
}
---
---setup treesitter
function M.setup()
    vim.treesitter.query.add_predicate("match-cellseparator?", M.match_cellseparator, { force = true, all = true })
    vim.treesitter.query.add_directive("set-cell-metadata!", M.set_cell_metadata, { force = true, all = true })
end

---@param line string
---@return string? type
---@return string title
---@return string metadata
function M.parse_separator(line)
    if line:match("^# %%%%$") then
        return "code", "", ""
    end
    local title, type, metadata = line:match("^# %%%% ([%w%s]*)%[(%w+)%](.*)$")

    if title then
        return cell_type_shorthands[type] or type, vim.trim(title), vim.trim(metadata)
    end
end

--- match cell separator
---@param match table<integer, TSNode[]>
---@param pattern integer
---@param source integer|string
---@param predicate any[]
---@return boolean?
function M.match_cellseparator(match, pattern, source, predicate)
    local node = match[predicate[2]][1]
    if not node then
        return false
    end

    -- print("match ",vim.inspect(match))
    -- print("pattern ",vim.inspect(predicate))
    -- local start_row, start_col = node:start()
    -- local is_start_of_line = vim.fn.indent(start_row + 1) == start_col
    -- if not is_start_of_line then
    --     return false
    -- end

    local text = vim.treesitter.get_node_text(node, source)
    -- print("text ",vim.inspect(text))
    local type, title = M.parse_separator(text)
    if not title then
        return false
    end
    if predicate[3] then
        local types = { unpack(predicate, 3) }
        return vim.tbl_contains(types, type)
    end
    return true
end

---@param match table<integer, TSNode[]>
---@param pattern integer
---@param source integer
---@param predicate any[]
---@param metadata vim.treesitter.query.TSMetadata
---@return boolean?
function M.set_cell_metadata(match, pattern, source, predicate, metadata)
    local node = match[predicate[2]][1]
    local text = vim.treesitter.get_node_text(node, source)

    local cell_type, cell_title, cell_metadata = M.parse_separator(text)
    metadata["cell-title"] = cell_title
    metadata["cell-type"] = cell_type
    metadata["cell-metadata"] = cell_metadata
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

function M.iter_capture_matches(buf, capture, query_name)
    local tree = vim.treesitter.get_parser(buf):trees()[1]
    local lang = vim.treesitter.language.get_lang(vim.bo[buf].ft)
    ---@cast lang -nil

    local query = vim.treesitter.query.get(lang, query_name)
    if not query then
        require("neopyter.utils").notify_warn(string.format("There is not `%s` query for lang=`%d`", query_name, lang))
        return vim.iter({})
    end

    ---@cast query -nil
    local root = tree:root()
    return vim.iter(query:iter_captures(root, buf)):filter(function(id)
        -- print(id)
        return capture == query.captures[id]
    end)
end

return M
