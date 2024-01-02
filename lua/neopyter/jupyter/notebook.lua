local options = require("neopyter.options")

---@class neopyter.Notebook
---@field private client neopyter.RpcClient
---@field buf number
---@field local_path string realative path
local Notebook = {
    bufnr = -1,
}
Notebook.__index = Notebook

---@class neopyter.NewNotebokOption
---@field client neopyter.RpcClient
---@field bufnr number
---@field local_path string

---Notebook Constructor, please don't call directly, obtain from jupyterlab
---@param o neopyter.NewNotebokOption
---@return neopyter.Notebook
function Notebook:create(o)
    o = setmetatable(o, self)
    o:_attach_event()
    return o --[[@as neopyter.Notebook]]
end

function Notebook:remote_path()
    return options.filename_mapper(self.local_path)
end

function Notebook:_attach_event()
    local augroup = vim.api.nvim_create_augroup(string.format("jupynium_buf_%d", self.bufnr), { clear = true })
    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
        buffer = self.bufnr,
        callback = function()
            local row, col = self:get_cursor_pos()
            -- TODO:scroll view, jump cell
        end,
        group = augroup,
    })

    vim.api.nvim_create_autocmd({ "ModeChanged" }, {
        buffer = self.bufnr,
        callback = function()
            local old_mode = vim.v.event.old_mode
            local new_mode = vim.v.event.new_mode
            local row, col = self:get_cursor_pos()
            -- TODO:change notebook mode to normal/insert
        end,
        group = augroup,
    })

    vim.api.nvim_create_autocmd({ "BufWritePre" }, {
        buffer = self.bufnr,
        callback = function()
            -- TODO:save notebook
        end,
        group = augroup,
    })

    vim.api.nvim_create_autocmd({ "BufUnload" }, {
        buffer = self.bufnr,
        callback = function()
            --TODO:close notebook, and select previous?
        end,
        group = augroup,
    })

    vim.api.nvim_buf_attach(self.bufnr, false, {
        on_lines = function(_, _, _, start_row, old_end_row, new_end_row, _)
            local lines = vim.api.nvim_buf_get_lines(self.bufnr, start_row, new_end_row, false)
            -- TODO:split cell, emit change
        end,
    })
end

---is exist corresponding notebok in remote server
function Notebook:is_exist()
    return self.client:request("isFileExist", self:remote_path())
end

function Notebook:is_open()
    return self.client:request("isFileOpen", self:remote_path())
end

function Notebook:create_new()
    return self.client:request("createNew", self:remote_path())
end

function Notebook:open()
    self.client:request("openFile", self:remote_path())
end

function Notebook:activate()
    self.client:request("openOrReveal", self:remote_path())
end

function Notebook:get_cell_nums() end

function Notebook:get_cursor_pos()
    local winid = vim.fn.bufwinid(self.bufnr)
    return vim.api.nvim_win_get_cursor(winid)
end

function Notebook:get_active_cell() end

return Notebook
