local a = require("plenary.async")
local utils = require("neopyter.utils")
local async_wrap = require("neopyter.asyncwrap")
local uv = a.uv
local api = a.api

---@class neopyter.Cell
---@field start_line number include
---@field lines string[]
---@field end_line number exclude
---@field source string
---@field title string
---@field no_separator? boolean
---@field cell_type? string
---@field cell_magic? string
---@field metadata? table<string, any>

---@class neopyter.Notebook
---@field private client neopyter.RpcClient
---@field bufnr number
---@field local_path string relative path
---@field remote_path string? #remote ipynb path
---@field private cells neopyter.Cell[]
---@field private active_cell_index number
---@field private augroup? number
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
function Notebook:new(o)
    local obj = setmetatable(o, self) --[[@as neopyter.Notebook]]
    local config = require("neopyter").config
    obj.remote_path = config.filename_mapper(obj.local_path)
    obj:_parse()
    return obj
end

---attach autocmd&notebook
function Notebook:attach()
    local augroup = api.nvim_create_augroup(string.format("neopyter-notebook-%d", self.bufnr), { clear = true })
    self.augroup = augroup
    utils.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
        buffer = self.bufnr,
        callback = function()
            local row, col = self:get_cursor_pos()
            local line_count = 0
            for index, cell in ipairs(self.cells) do
                line_count = line_count + #cell.lines
                if line_count >= row then
                    local active_index = index - 1
                    if active_index ~= self.active_cell_index then
                        -- cache
                        self.active_cell_index = active_index
                        self:activate_cell(active_index)
                        self:scroll_to_item(active_index, "smart")
                    end
                    break
                end
            end
        end,
        group = augroup,
    })

    utils.nvim_create_autocmd({ "ModeChanged" }, {
        buffer = self.bufnr,
        callback = function()
            local old_mode = vim.v.event.old_mode
            local new_mode = vim.v.event.new_mode
            local row, col = self:get_cursor_pos()
            -- TODO:change notebook mode to normal/insert
        end,
        group = augroup,
    })

    utils.nvim_create_autocmd({ "BufWritePre" }, {
        buffer = self.bufnr,
        callback = function()
            self:save()
        end,
        group = augroup,
    })

    api.nvim_buf_attach(self.bufnr, false, {
        on_lines = function(_, _, _, start_row, old_end_row, new_end_row, _)
            a.run(function()
                -- TODO:particle update
                self:_parse()
                self:full_sync()
            end, function() end)
        end,
    })

    self:full_sync()
end

function Notebook:detach()
    api.nvim_del_augroup_by_id(self.augroup)
    self.augroup = nil
end

function Notebook:is_attached()
    return self.augroup ~= nil
end

---internal request
---@param method string
---@param ... any
---@return any
---@package
function Notebook:_request(method, ...)
    return self.client:request(method, self.remote_path, ...)
end

---is exist corresponding notebook in remote server
function Notebook:is_exist()
    return self:_request("isFileExist")
end

function Notebook:is_open()
    return self:_request("isFileOpen")
end

function Notebook:create_new()
    return self:_request("createNew")
end

function Notebook:open()
    return self:_request("openFile")
end

function Notebook:activate()
    return self:_request("openOrReveal")
end

function Notebook:activate_cell(idx)
    return self:_request("activateCell", idx)
end

---scroll to item
---@param idx number
---@param align? 'auto'|'smart'|'center'|'start'|'end'
---@param margin? number
---@return unknown|nil
function Notebook:scroll_to_item(idx, align, margin)
    return self:_request("scrollToItem", idx, align, margin)
end

function Notebook:get_cell_num()
    return self:_request("getCellNum")
end

function Notebook:get_cursor_pos()
    local winid = vim.fn.bufwinid(self.bufnr)
    local pos = vim.api.nvim_win_get_cursor(winid)
    return pos[1], pos[2]
end

function Notebook:get_active_cell() end

function Notebook:full_sync()
    local cells = vim.tbl_map(function(cell)
        return {
            source = cell.source,
            cell_type = cell.cell_type,
        }
    end, self.cells)
    self:_request("setCellNum", #cells)
    self:_request("syncCells", 0, cells)
end

---save ipynb, same as `Ctrl+S` on jupyter lab
---@return boolean
function Notebook:save()
    return self:_request("save")
end

function Notebook:run_selected_cell()
    return self:_request("runSelectedCell")
end

function Notebook:run_all_above()
    return self:_request("runAllAbove")
end

function Notebook:run_all_below()
    return self:_request("runAllBelow")
end

function Notebook:run_all()
    return self:_request("runAll")
end

function Notebook:restart_kernel()
    return self:_request("restartKernel")
end

function Notebook:restart_run_all()
    return self:_request("restartRunAll")
end

function Notebook:_parse()
    local lines = vim.api.nvim_buf_get_lines(self.bufnr, 0, -1, true)
    self.cells = utils.parse_content(lines)
end

Notebook = async_wrap(Notebook, { "is_attached" })

return Notebook
