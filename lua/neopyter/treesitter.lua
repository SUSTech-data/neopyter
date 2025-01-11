local Path = require("plenary.path")
local utils = require("neopyter.utils")
local a = require("neopyter.async")
local uv = a.uv
local fn = a.fn
local api = a.api

--- @brief Neopyter don't depend on `nvim-treesitter`, this module provides some utility related to `treesitter`, such as capture and match.
---
--- Example:
---
--- ```lua
--- local ts = require("neopyter.treesitter")
--- ts.get_buf_lang(0)
---
--- ```

local treesitter = {}

function treesitter.get_buf_lang(buf)
    local tree = vim.treesitter.get_parser(buf):trees()[1]
    return vim.treesitter.language.get_lang(vim.bo[buf].ft)
end

---load query to RTP
---@param query string
---@param lang string? # language (default python)
---@param name string? # the prefix name
function treesitter.load_query(query, lang, name)
    lang = lang or "python"

    ---@type Path
    local cache_path = Path:new(a.fn.tempname()) / "neopyter"
    if name then
        cache_path = cache_path / name
    end
    ---@type Path
    local target_path = cache_path / "queries" / lang / (query .. ".scm")

    ---@type Path
    local plugin_path = utils.get_plugin_path()
    ---@type Path
    local source_path
    if name then
        source_path = plugin_path / "res" / "queries" / lang / query / (name .. ".scm")
    else
        source_path = plugin_path / "res" / "queries" / lang / (query .. ".scm")
    end
    if not source_path:exists() then
        utils.notify_warn(string.format("The query %s don't exists in %s", query, source_path))
        return
    end

    target_path:parent():mkdir({ parents = true, exists_ok = true })
    source_path:copy({ destination = target_path, parents = true })
    vim.opt.rtp:prepend(tostring(cache_path))
end

---get captures
---@param query vim.treesitter.Query
---@param source vim.treesitter.LanguageTree|number|string|(string[])
---@param capture string
---@param start integer?
---@param stop integer?
---@param loop boolean?
---@return Iter
function treesitter.iter_captures(query, source, capture, start, stop, loop)
    local lang = query.lang
    local lang_tree
    if type(source) == "number" then
        lang_tree = vim.treesitter.get_parser(source, lang, { injections = { [lang] = "" } })
    elseif type(source) == "string" then
        lang_tree = vim.treesitter.get_string_parser(source, lang, { injections = { [lang] = "" } })
    elseif vim.islist(source) then
        source = table.concat(source, "\n")
        lang_tree = vim.treesitter.get_string_parser(source, lang, { injections = { [lang] = "" } })
    else
        lang_tree = source
    end
    ---@cast lang_tree -nil
    local root = lang_tree:parse()[1]:root()

    local iter = query:iter_captures(root, lang_tree:source(), start, stop)
    return vim.iter(function()
        local ret = { iter() }
        if #ret < 1 and loop then
            iter = query:iter_captures(root, lang_tree:source(), start, stop)
            ret = { iter() }
        end
        return unpack(ret)
    end)
        :filter(function(id, node)
            ---- FIX: https://github.com/neovim/neovim/issues/31963
            if stop then
                return query.captures[id] == capture and node:end_() < stop
            end
            return query.captures[id] == capture
        end)
        :map(function(_, node, metadata, match)
            return node, metadata, match
        end)
end

---get captures
---@param query vim.treesitter.Query
---@param source vim.treesitter.LanguageTree|number|string|(string[])
---@param start integer?
---@param stop integer?
---@param loop boolean?
---@return Iter
function treesitter.iter_matches(query, source, start, stop, loop)
    local lang_tree
    if type(source) == "number" then
        lang_tree = vim.treesitter.get_parser(source, query.lang)
    elseif type(source) == "string" then
        lang_tree = vim.treesitter.get_string_parser(source, query.lang)
    elseif vim.islist(source) then
        source = table.concat(source, "\n")
        lang_tree = vim.treesitter.get_string_parser(source, query.lang)
    else
        lang_tree = source
    end
    ---@cast lang_tree -nil
    local root = lang_tree:parse()[1]:root()

    local iter = query:iter_matches(root, lang_tree:source(), start, stop)
    return vim.iter(function()
        local ret = { iter() }
        if #ret < 1 and loop then
            iter = query:iter_matches(root, lang_tree:source(), start, stop)
            ret = { iter() }
        end
        return unpack(ret)
    end)
end

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
function treesitter.include_whitespace(bufnr, textobject, selection_mode)
    local start_row, start_col, end_row, end_col = unpack(textobject)
    while is_whitespace_after(bufnr, end_row, end_col) do
        end_row, end_col = next_position(bufnr, end_row, end_col, true)
    end
    if end_col == 0 and selection_mode == "linewise" then
        end_row, end_col = next_position(bufnr, end_row, end_col, false)
    end
    return { start_row, start_col, end_row, end_col }
end
return treesitter
