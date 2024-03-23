local query = require("nvim-treesitter.query")

local M = {}

local function get_char_after_position(bufnr, row, col)
    if row == nil then
        return nil
    end
    local ok, char = pcall(vim.api.nvim_buf_get_text, bufnr, row, col, row, col + 1, {})
    if ok then
        return char[1]
    end
end

local function is_whitespace_after(bufnr, row, col)
    local char = get_char_after_position(bufnr, row, col)
    if char == nil then
        return false
    end
    if char == "" then
        if row == vim.api.nvim_buf_line_count(bufnr) - 1 then
            return false
        else
            return true
        end
    end
    return string.match(char, "%s")
end

local function get_line(bufnr, row)
    return vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
end

---comment
---@param bufnr number
---@param row number
---@param col number
---@param forward boolean
---@return number|nil row
---@return number|nil col
local function next_position(bufnr, row, col, forward)
    local max_col = #get_line(bufnr, row)
    local max_row = vim.api.nvim_buf_line_count(bufnr)
    if forward then
        if col == max_col then
            if row == max_row then
                return nil
            end
            row = row + 1
            col = 0
        else
            col = col + 1
        end
    else
        if col == 0 then
            if row == 0 then
                return nil
            end
            row = row - 1
            col = #get_line(bufnr, row)
        else
            col = col - 1
        end
    end
    return row, col
end

---include surrounding whitespace
---@param bufnr number
---@param textobject number[] (start_row, start_col, end_row, end_col) tuple for textobject position, TSNode:range() like
---@param selection_mode 'linewise'|'charwise'
---@return table
function M.include_whitespace(bufnr, textobject, selection_mode)
    local start_row, start_col, end_row, end_col = unpack(textobject)
    while is_whitespace_after(bufnr, end_row, end_col) do
        end_row, end_col = next_position(bufnr, end_row, end_col, true)
    end
    if end_col == 0 and selection_mode == "linewise" then
        end_row, end_col = next_position(bufnr, end_row, end_col, false)
    end
    return { start_row, start_col, end_row, end_col }
end

return M
