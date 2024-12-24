local ts = require("neopyter.treesitter")
local Parser = require("neopyter.parser.parser")

---@class neopyter.PercentParser: neopyter.Parser
---@field extract_string_query vim.treesitter.Query
---@field extract_string_capture string
local PercentParser = Parser:new()
PercentParser.__index = PercentParser

---@class neopyter.PercentParserOption: neopyter.ParserOption

---constructor of PercentParser
---@param opt neopyter.PercentParserOption
---@return neopyter.PercentParser
function PercentParser:new(opt)
    local obj = vim.tbl_deep_extend("force", {}, opt or {}) --[[@as neopyter.PercentParser]]
    obj = setmetatable(obj, self)
    obj.separator_query = vim.treesitter.query.parse(
        "python",
        [[
            (module
              (comment) @cellseparator
              (#match-percent-separator? @cellseparator)
              (#set-percent-metadata! @cellseparator)
            )
        ]]
    )
    obj.extract_string_capture = "cellcontent"
    obj.extract_string_query = vim.treesitter.query.parse(
        "python",
        [[
            (module
                (expression_statement
                    (string
                        (string_start) 
                        (string_content) @cellcontent
                        (string_end)
                    )
                )
            )
        ]]
    )

    vim.treesitter.query.add_predicate("match-percent-separator?", PercentParser.match_cellseparator, { force = true, all = true })
    vim.treesitter.query.add_directive("set-percent-metadata!", PercentParser.set_percent_metadata, { force = true, all = true })
    return obj
end

local cell_type_shorthands = {
    md = "markdown",
}

---@param line string
---@return string? type
---@return string? title
---@return string? metadata
function PercentParser.parse_percent(line)
    local function to_type(type)
        return cell_type_shorthands[type] or type
    end
    if string.sub(line, 1, 4) ~= "# %%" then
        return
    end
    local title, type, metadata
    if line == "# %%" then
        return "code"
    end
    if not line:match("^# %%%%%s") then
        return
    end
    type = line:match("^# %%%%%s+%[(%w+)%]%s*$")
    if type then
        return to_type(type)
    end
    title, type = line:match("^# %%%%%s+(%w+)%s+%[(%w+)%]%s*$")
    if title then
        return to_type(type), vim.trim(title)
    end
    type, metadata = line:match("^# %%%%%s+%[(%w+)%]%s+(.+)%s*$")
    if type then
        return to_type(type), nil, vim.trim(metadata)
    end
    title, type, metadata = line:match("^# %%%%%s+([%w%s]*)%s+%[(%w+)%]%s+(.*)$")
    if title then
        return to_type(type), vim.trim(title), vim.trim(metadata)
    end

    return "code", vim.trim(line:sub(6))
end

--- match cell separator
---@param match table<integer, TSNode[]>
---@param pattern integer
---@param source integer|string
---@param predicate any[]
---@return boolean?
function PercentParser.match_cellseparator(match, pattern, source, predicate)
    return vim.iter(match[predicate[2]] or {}):all(function(node)
        local _, start_col = node:start()
        if start_col ~= 0 then
            return false
        end

        local text = vim.treesitter.get_node_text(node, source)
        local type, title = PercentParser.parse_percent(text)
        if not type then
            return false
        end
        if predicate[3] then
            local types = { unpack(predicate, 3) }
            return vim.tbl_contains(types, type)
        end
        return true
    end)
end

---@param match table<integer, TSNode[]>
---@param pattern integer
---@param source integer
---@param predicate any[]
---@param metadata vim.treesitter.query.TSMetadata
---@return boolean?
function PercentParser.set_percent_metadata(match, pattern, source, predicate, metadata)
    local node = match[predicate[2]][1]
    local text = vim.treesitter.get_node_text(node, source)

    local cell_type, cell_title, cell_metadata = PercentParser.parse_percent(text)
    metadata["cell-title"] = cell_title
    metadata["cell-type"] = cell_type
    metadata["cell-metadata"] = cell_metadata
end

---get iteration of cell
---@param source number|string|string[]  buffer or source code
---@param start integer # zero default
---@param stop integer # full default
---@return Iter # ICell source
function PercentParser:iter_cell(source, start, stop)
    local caps = ts.iter_captures(self.separator_query, source, self.separator_capture, start, stop):totable()
end

---get each cell range
---@param source number|string|string[]  buffer or source code
---@return neopyter.INotebook
function PercentParser:parse_notebook(source)
    local last_row

    local lang_tree
    if type(source) == "number" then
        lang_tree = vim.treesitter.get_parser(source, self.separator_query.lang)
        last_row = vim.api.nvim_buf_line_count(source) - 1
    elseif type(source) == "string" then
        lang_tree = vim.treesitter.get_string_parser(source, self.separator_query.lang)
        last_row = #vim.split(source, "\n") - 1
    elseif vim.islist(source) then
        last_row = #source - 1
        source = table.concat(source, "\n")
        lang_tree = vim.treesitter.get_string_parser(source, self.separator_query.lang)
    end
    ---@cast lang_tree -nil

    ---@type TSNode
    local root = lang_tree:parse()[1]:root()
    ---@type {node: TSNode, metadata: vim.treesitter.query.TSMetadata, match: TSQueryMatch}[]
    local captures = ts.iter_captures(self.separator_query, lang_tree, self.separator_capture)
        :map(function(node, metadata, match)
            return {
                node = node,
                metadata = metadata,
                match = match,
            }
        end)
        :totable()
    if #captures < 1 then
        return {
            cells = {
                {
                    -- parser:line
                    start_row = 0,
                    end_row = last_row,
                    type = "code",
                    no_separator = true,
                },
            },
        }
    end
    ---@type neopyter.ICell[]
    local cells = {}
    ---@type table
    local notebook_metadata

    local i = 1
    while i <= #captures do
        local node, metadata = captures[i].node, captures[i].metadata
        if i == 1 and node:start() ~= 0 then --TODO: notebook metadata
            --TODO: parser notebook notedata
            table.insert(cells, {
                start_row = 0,
                end_row = node:end_() - 1,
                no_separator = true,
                type = "code",
            })
        end
        if i < #captures then
            local next_node = captures[i + 1].node
            table.insert(cells, {
                start_row = node:start(),
                end_row = next_node:start() - 1,
                type = metadata["cell-type"],
                title = metadata["cell-title"],
                metadata = metadata["cell-metadata"],
            })
        else
            --last cell
            table.insert(cells, {
                start_row = node:start(),
                end_row = last_row,
                type = metadata["cell-type"],
                title = metadata["cell-title"],
                metadata = metadata["cell-metadata"],
            })
        end

        i = i + 1
    end
    return {
        cells = cells,
        metadata = notebook_metadata,
    }
end

---parser next cell body
---@param source integer
---@param start integer # include, 0-based
---@param stop integer # include, 0-based
function PercentParser:parser_cell_body(source, start, stop)
    local content
    local caps = ts.iter_captures(self.extract_string_query, source, self.extract_string_capture, start, stop + 1):totable()
    if #caps == 1 then
        content = vim.treesitter.get_node_text(caps[1][1], source)
        local first_nl = content:find("\n")
        -- remove first new line
        if first_nl then
            content = content:sub(first_nl + 1)
        end
    else
        content = vim.api.nvim_buf_get_lines(source, start, stop + 1, true)
        local is_comment_start = vim.iter(content):all(function(line)
            if vim.trim(line) == "" then
                return true
            end
            return vim.startswith(line, "# ")
        end)
        -- each line is start with  `# `
        if is_comment_start then
            content = vim.iter(content)
                :map(function(line)
                    if vim.trim(line) == "" then
                        return line
                    end
                    return line:sub(3)
                end)
                :join("\n")
        end
    end

    if type(content) == "table" then
        content = table.concat(content, "\n")
    end
    return content
end

---parse cell source
---@param source number  # buffer
---@param cell neopyter.ICell
function PercentParser:parse_source(source, cell)
    ---@type string|string[]
    local content
    local start_row = cell.start_row
    local end_row = cell.end_row

    if not cell.no_separator then
        start_row = start_row + 1
    end
    if cell.type == "code" then
        if not cell.no_separator and start_row <= end_row then
            local first_line = vim.api.nvim_buf_get_lines(source, start_row, start_row + 1, false)[1]
            if first_line and first_line:match("# %%%%%w+") then
                content = first_line:sub(3)
                if start_row < cell.end_row then
                    local cell_body = self:parser_cell_body(source, start_row + 1, cell.end_row)
                    content = content .. "\n" .. cell_body
                end
                goto parsed
            end
        end
        content = vim.api.nvim_buf_get_lines(source, start_row, end_row + 1, true)
        content = vim.iter(content)
            :map(function(line)
                if line:match("# %%%w+") then
                    -- line magic
                    line = line:sub(3)
                end
                return line
            end)
            :totable()
        if not cell.no_separator and #content > 0 and content[1]:match("# %%%%%w+") then
            -- cell magic
        end
    elseif cell.type == "markdown" or cell.type == "raw" then
        content = self:parser_cell_body(source, cell.start_row + 1, cell.end_row)
    end

    ::parsed::
    if type(content) == "table" then
        content = table.concat(content, "\n")
    end
    ---@cast content string
    if self.trim_whitespace then
        content = vim.trim(content)
    end
    return content
end

return PercentParser
