local a = require("plenary.async")
local utils = require("neopyter.utils")
local async_wrap = require("neopyter.asyncwrap")
local api = a.api

---@alias neopyter.ScrollToAlign 'center' | 'top-center' | 'start' | 'end'| 'auto' | 'smart'

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
---@field private _is_exist boolean
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
    return obj
end

---attach autocmd&notebook
function Notebook:attach()
    local config = require("neopyter").config
    if self.augroup == nil then
        self.augroup = api.nvim_create_augroup(string.format("neopyter-notebook-%d", self.bufnr), { clear = true })
        if config.jupyter.scroll.enable then
            utils.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
                buffer = self.bufnr,
                callback = function()
                    if not self:safe_sync() then
                        return
                    end
                    local index = self:get_cursor_cell_pos()
                    if index ~= self.active_cell_index then
                        -- cache
                        self.active_cell_index = index
                        self:activate_cell(index - 1)
                        self:scroll_to_item(index - 1, config.jupyter.scroll.align)
                    end
                end,
                group = self.augroup,
            })
        end

        utils.nvim_create_autocmd({ "BufWritePre" }, {
            buffer = self.bufnr,
            callback = function()
                if self:safe_sync() then
                    self:save()
                end
            end,
            group = self.augroup,
        })
        api.nvim_buf_attach(self.bufnr, false, {
            on_lines = function(_, _, _, start_row, old_end_row, new_end_row, _)
                a.run(function()
                    if not self:safe_sync() then
                        self:update_cells()
                        return
                    end
                    self:partial_sync(start_row, old_end_row, new_end_row)
                end, function() end)
            end,
        })
    end

    self:update_cells()
    self._is_exist = nil
    if self:is_connecting() then
        self:open_or_reveal()
        self:activate()
        -- initial full sync
        self:full_sync()
    end
end

--- detach autocmd
function Notebook:detach()
    api.nvim_del_augroup_by_id(self.augroup)
    -- detach buf
    self.augroup = nil
end

--- check attach status
---@return boolean
function Notebook:is_attached()
    return self.augroup ~= nil
end

function Notebook:is_connecting()
    if self.client:is_connecting() then
        if self._is_exist ~= nil then
            return self._is_exist
        else
            self._is_exist = self:is_exist()
            return self._is_exist
        end
    end
    return false
end

function Notebook:safe_sync()
    if self:is_connecting() then
        self:open_or_reveal()
        return true
    end
    return false
end

function Notebook:update_cells()
    local lines = api.nvim_buf_get_lines(self.bufnr, 0, -1, true)
    self.cells = utils.parse_content(lines)
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

--- whether corresponding `.ipynb` file opened in jupyter lab or not
---@return boolean
function Notebook:is_open()
    return self:_request("isFileOpen")
end

function Notebook:create_new()
    return self:_request("createNew")
end

function Notebook:open()
    return self:_request("openFile")
end

function Notebook:open_or_reveal()
    return self:_request("openOrReveal")
end

function Notebook:activate()
    return self:_request("activateNotebook")
end

function Notebook:activate_cell(idx)
    return self:_request("activateCell", idx)
end

---scroll to item
---@param idx number
---@param align? neopyter.ScrollToAlign
---@param margin? number
---@return unknown|nil
function Notebook:scroll_to_item(idx, align, margin)
    return self:_request("scrollToItem", idx, align, margin)
end

function Notebook:get_cell_num()
    return self:_request("getCellNum")
end

function Notebook:get_cursor_pos()
    local winid = utils.buf2winid(self.bufnr)

    local pos = api.nvim_win_get_cursor(winid or 0)
    return pos[1], pos[2]
end

---@param pos integer[] (row, col) tuple representing the new position
function Notebook:set_cursor_pos(pos)
    local winid = utils.buf2winid(self.bufnr)
    ---@cast winid -nil
    vim.api.nvim_win_set_cursor(winid, pos)
end

---get current cell of cursor position, start from 1
---@return number #index of cell
---@return number #row of cursor in cell
---@return number #col of cursor in cell
function Notebook:get_cursor_cell_pos()
    local row, col = self:get_cursor_pos()
    local line_count = 0
    for index, cell in ipairs(self.cells) do
        local next_count = line_count + #cell.lines
        if next_count >= row then
            return index, row - line_count, col
        end
        line_count = next_count
    end
    return #self.cells, 0, 0
end

---get cell by index
---@param idx number
---@return neopyter.Cell
function Notebook:get_cell(idx)
    return self.cells[idx]
end

function Notebook:full_sync()
    local cells = vim.tbl_map(function(cell)
        return {
            source = cell.source,
            cell_type = cell.cell_type,
        }
    end, self.cells)
    self:_request("fullSync", cells)
end

---@diagnostic disable-next-line: unused-local
function Notebook:partial_sync(start_row, old_end_row, new_end_row)
    ---TODO:real partial sync via treesitter query
    --- need support custom directive via vim.treesitter.query.add_directive({all=true})
    assert(self.cells ~= nil, "must exist cells")
    local lines = api.nvim_buf_get_lines(self.bufnr, 0, -1, true)
    local new_cells = utils.parse_content(lines)

    -- new cells length
    local ncl = #new_cells
    -- old cells length
    local ocl = #self.cells

    local i = 0
    while i < ncl and i < ocl do
        i = i + 1
        local nc = new_cells[i]
        local oc = self.cells[i]
        if table.concat(nc.lines, "\n") ~= table.concat(oc.lines, "\n") then
            break
        end
    end

    local j = -1
    while j < ncl - 1 and j < ocl - 1 do
        j = j + 1
        if (ncl - j) == i or (ocl - j) == i then
            break
        end
        local nc = new_cells[ncl - j]
        local oc = self.cells[ocl - j]
        if table.concat(nc.lines, "\n") ~= table.concat(oc.lines, "\n") then
            break
        end
    end
    -- update local state first
    self.cells = new_cells

    -- the different cells(index from 1):
    -- new_cells: from i to ncl - j
    -- old_cells: from i to ocl - j
    local partial_cells = { unpack(new_cells, i, ncl - j) }
    self:_request("partialSync", i - 1, ocl - j - 1, partial_cells)
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

---@alias neopyter.NotebookMode
---| 'command'
---| 'edit'

---set notebook mode
---@param mode neopyter.NotebookMode
function Notebook:set_mode(mode)
    return self:_request("setMode", mode)
end

---complete
---@param params {source: string, offset: number, cellIndex: number}
---@return {label: string, type: string, insertText:string, source: string}[]
function Notebook:complete(params)
    return self:_request("complete", params)
end

---kernel complete
---@param source string
---@param offset number
---@return {label: string, type: string, insertText:string, source: string}[]
function Notebook:kernel_complete(source, offset)
    return self:_request("kernelComplete", source, offset)
end

Notebook = async_wrap(Notebook, {
    "update_cells",
    "is_attached",
})

return Notebook
