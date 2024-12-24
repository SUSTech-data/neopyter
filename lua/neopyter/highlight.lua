local utils = require("neopyter.utils")
local ts = require("neopyter.treesitter")
local a = require("neopyter.async")
local api = a.api
local fn = a.fn

---@class neopyter.HighlightOption
---@field enable boolean
---@field mode "zen"|"separator"

---@nodoc
---@class neopyter.Highlight
---@field query {[string]: vim.treesitter.Query}
local M = {}
local ns_highlight = vim.api.nvim_create_namespace("neopyter-highlighter")

---setup/update highlight module
---@nodoc
function M.setup()
    local config = require("neopyter").config.highlight
    ---@cast config -nil
    local validator = {
        enable = { config.enable, "boolean" },
        mode = {
            config.mode,
            function(mode)
                if mode == "zen" or mode == "separator" then
                    return true
                end
                return false
            end,
            "one of `zen`, `separator`",
        },
    }
    utils.validate_config("highlight", validator, config)
    if not config.enable then
        return
    end

    M.query = {
        python = vim.treesitter.query.parse(
            "python",
            [[
                (module
                  (comment) @cellseparator
                  (#match-percent-separator? @cellseparator)
                )
            ]]
        ),
    }
end

local function update_zen_highlight(buf)
    api.nvim_buf_clear_namespace(0, ns_highlight, 0, -1)
    api.nvim_set_hl(ns_highlight, "NeopyterDim", { link = "DiagnosticUnnecessary", default = true })
    local notebook = require("neopyter.jupyter.jupyterlab"):get_notebook(buf)
    if not notebook then
        utils.notify_warn("Can't highlight buffer: cann't find notebook")
        return
    end
    local cell = notebook:get_cell()
    if not cell then
        -- utils.notify_warn("Can't highlight buffer: cann't locate cell")
        -- code don't parse
        return
    end

    local start_row = cell.start_row
    local end_row = cell.end_row

    for i = fn.line("w0") - 1, fn.line("w$") - 1 do
        if i < start_row or i > end_row then
            api.nvim_buf_set_extmark(0, ns_highlight, i, 0, {
                end_row = i + 1,
                end_col = 0,
                hl_group = "DiagnosticUnnecessary",
                priority = 9000,
                hl_eol = true,
            })
        end
    end
end

---highlight node
---@param node TSNode
---@param hl_group string|number
---@param mode 'charwise'|'linewise'
---@param include_whitespace boolean
---@param priority number
local function highlight_node(node, hl_group, mode, include_whitespace, priority)
    local range = { node:range(false) }
    if include_whitespace then
        range = ts.include_whitespace(0, range, mode)
    end
    local start_row, start_col, end_row, end_col = unpack(range)

    if mode == "linewise" then
        api.nvim_buf_set_extmark(0, ns_highlight, start_row, 0, {
            end_line = end_row + 1,
            end_col = 0,
            hl_group = hl_group,
            hl_eol = true,
            priority = priority,
        })
    else
        api.nvim_buf_set_extmark(0, ns_highlight, start_row, start_col, {
            end_line = end_row,
            end_col = end_col,
            hl_group = hl_group,
            hl_eol = false,
            priority = priority,
        })
    end
end

local function update_separator_highlight(buf)
    api.nvim_buf_clear_namespace(0, ns_highlight, 0, -1)

    api.nvim_set_hl(ns_highlight, "NeopyterSeparator", { link = "CursorLine" })

    -- print(vim.inspect(M.query))
    -- print(vim.inspect(ts.get_buf_lang(buf)))
    local query = M.query[ts.get_buf_lang(buf)]
    ts.iter_captures(query, 0, "cellseparator"):each(function(node)
        highlight_node(node, "CursorLine", "linewise", true, 9001)
    end)
end

---@nodoc
function M.attach(buf, augroup)
    local config = require("neopyter").config.highlight
    local updated = false
    if not config or not config.enable then
        return
    end

    if config.mode == "zen" then
        utils.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "WinScrolled" }, {
            buffer = buf,
            callback = function()
                updated = false
                -- throttling
                a.defer_fn(function()
                    if updated == false then
                        updated = true
                        update_zen_highlight(buf)
                    end
                end, 50)
            end,
            group = augroup,
        })
    else
        utils.nvim_create_autocmd({ "BufWinEnter", "BufWritePost", "TextChanged", "TextChangedI" }, {
            buffer = buf,
            callback = function()
                updated = false
                a.defer_fn(function()
                    if updated == false then
                        updated = true
                        update_separator_highlight(buf)
                    end
                end, 50)
            end,
            group = augroup,
        })
    end
end

return M
