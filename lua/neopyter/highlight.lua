-- Code mostly based on koenverburg/peepsight.nvim
local utils = require("neopyter.utils")
local query = require("nvim-treesitter.query")
local textobjects = require("neopyter.textobjects")

---@class neopyter.HighlightOption
---@field enable boolean
---@field shortsighted boolean

local M = {}
local ns_highlight = vim.api.nvim_create_namespace("neopyter-highlighter")

---setup/update highlight module
---@param opts neopyter.HighlightOption
function M.setup(opts)
    if opts.enable then
        local config = require("neopyter").config
        local augroup = vim.api.nvim_create_augroup("neopyter-highlighter", {})
        local updated = false
        if opts.shortsighted then
            vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "WinScrolled" }, {
                pattern = config.file_pattern,
                callback = function()
                    updated = false
                    vim.defer_fn(function()
                        if updated == false then
                            updated = true
                            M.update_dynamic_highlight()
                        end
                    end, 10)
                end,
                group = augroup,
            })
        else
            vim.api.nvim_create_autocmd({ "BufWinEnter", "BufWritePost", "TextChanged", "TextChangedI" }, {
                pattern = config.file_pattern,
                callback = function()
                    updated = false
                    vim.defer_fn(function()
                        if updated == false then
                            updated = true
                            M.update_static_highlight()
                        end
                    end, 10)
                end,
                group = augroup,
            })
        end
    end
end

function M.update_static_highlight()
    vim.api.nvim_buf_clear_namespace(0, ns_highlight, 0, -1)

    -- code cell separator
    M.highlight_capture({ "@cellseparator.code", "@cellseparator.magic" }, "CursorLine", "linewise", false, 9000)
    -- markdown cell
    M.highlight_capture({ "@cell.markdown", "@cell.raw", "@cell.special" }, "CursorLine", "linewise", true, 9000)
    -- line magic
    M.highlight_capture({ "@linemagic" }, "Keyword", "charwise", false, 9000)
end

function M.update_dynamic_highlight()
    vim.api.nvim_buf_clear_namespace(0, ns_highlight, 0, -1)

    local matches = query.get_capture_matches(0, "@cell", "textobjects")

    local currentIndex
    --- @type TSNode[]
    local nodes = vim.tbl_map(function(match)
        return match[vim.tbl_keys(match)[1]].node
    end, matches or {})

    local row = vim.api.nvim_win_get_cursor(0)[1] - 1
    for index, node in ipairs(nodes) do
        local start_row = node:start()
        if start_row <= row then
            currentIndex = index
        else
            break
        end
    end

    M.highlight_capture({ "@linemagic" }, "Keyword", "charwise", false, 9000)
    for index, node in ipairs(nodes) do
        if currentIndex == index then
            -- M.highlight_node(node, "Comment", "linewise", true, 9001)
        else
            M.highlight_node(node, "Comment", "linewise", true, 9001)
            M.highlight_node(node, "CursorLine", "linewise", true, 9001)
        end
    end
end

---highligh captures
---@param captures string|string[]
---@param hl_group string|number
---@param mode "charwise"|"linewise"
---@param include_whitespace boolean
---@param priority number
function M.highlight_capture(captures, hl_group, mode, include_whitespace, priority)
    local matches = query.get_capture_matches(0, captures, "textobjects")
    for _, match in ipairs(matches or {}) do
        --- @type TSNode
        local node = match.node
        if node then
            M.highlight_node(node, hl_group, mode, include_whitespace, priority)
        else
            print("Error textobjects query:", vim.inspect(match))
        end
    end
end

---highlight node
---@param node TSNode
---@param hl_group string|number
---@param mode 'charwise'|'linewise'
---@param include_whitespace boolean
---@param priority number
function M.highlight_node(node, hl_group, mode, include_whitespace, priority)
    local range = { node:range(false) }
    if include_whitespace then
        range = textobjects.include_whitespace(0, range, mode)
        -- print(vim.inspect(range))
    end
    local start_row, start_col, end_row, end_col = unpack(range)

    if mode == "linewise" then
        vim.api.nvim_buf_set_extmark(0, ns_highlight, start_row, 0, {
            end_line = end_row + 1,
            end_col = 0,
            hl_group = hl_group,
            hl_eol = true,
            priority = priority,
        })
    else
        vim.api.nvim_buf_set_extmark(0, ns_highlight, start_row, start_col, {
            end_line = end_row,
            end_col = end_col,
            hl_group = hl_group,
            hl_eol = false,
            priority = priority,
        })
    end
end

return M
