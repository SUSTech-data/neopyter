-- Code mostly based on koenverburg/peepsight.nvim
local utils = require("neopyter.utils")
local query = require("nvim-treesitter.query")

---@class neopyter.HighlightOption
---@field enable boolean true

local M = {}

---setup/update highlight module
---@param opts neopyter.HighlightOption
function M.setup(opts)
    if opts.enable then
        vim.api.nvim_set_hl(0, "@cell.header", { link = "CursorLine" })
        vim.api.nvim_set_hl(0, "@cell.border", { link = "Comment" })
        M.set_autocmd()
    end
end

local ns_highlight = vim.api.nvim_create_namespace("neopyter-highlighter")

function M.update()
    vim.api.nvim_buf_clear_namespace(0, ns_highlight, 0, -1)
    local matches = query.get_capture_matches(0, { "@cell.header" }, "highlights")

    for _, match in ipairs(matches or {}) do
        --- @type TSNode
        local node = match[vim.tbl_keys(match)[1]].node
        local row, _, _ = node:start()
        vim.api.nvim_buf_set_extmark(0, ns_highlight, row, 0, {
            end_line = row + 1,
            end_col = 0,
            hl_group = "@cell.header",
            hl_eol = true,
            priority = 0,
        })
    end
end

function M.set_autocmd()
    local config = require("neopyter").config
    local augroup = vim.api.nvim_create_augroup("jupynium-highlighter", {})
    vim.api.nvim_create_autocmd({ "BufWinEnter", "BufWritePost", "CursorMoved", "CursorMovedI", "WinScrolled" }, {
        pattern = config.file_pattern,
        callback = M.update,
        group = augroup,
    })
end

return M
