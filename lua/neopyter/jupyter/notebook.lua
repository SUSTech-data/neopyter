local utils = require("neopyter.utils")
local a = require("neopyter.async")
local api = a.api

--- @brief Neopyter provide `neopyter.Notebook` represent remote `Notebook` instance,
--- which provides some RPC-based API to control remote `Notebook` instance.
--- Obtain notebook refer to `neopyter-jupyterlab-api`

---@alias neopyter.ScrollToAlign 'center' | 'top-center' | 'start' | 'end'| 'auto' | 'smart'

---@nodoc
---@class neopyter.Notebook:neopyter.INotebook
---@field private client neopyter.RpcClient
---@field bufnr number
---@field local_path string relative path
---@field remote_path string? #remote ipynb path
---@field private cells neopyter.ICell[]
---@field private metadata? table
---@field private active_cell_index number
---@field private augroup? number
---@field private _is_exist boolean
local Notebook = {
    bufnr = -1,
}
Notebook.__index = Notebook

---@nodoc
---@class neopyter.NewNotebokOption
---@field client neopyter.RpcClient
---@field bufnr number
---@field local_path string

---Notebook Constructor, please don't call directly, obtain from jupyterlab
---@nodoc
---@param o neopyter.NewNotebokOption
---@return neopyter.Notebook
function Notebook:new(o)
    local obj = setmetatable(o, self) --[[@as neopyter.Notebook]]
    local config = require("neopyter").config
    obj.remote_path = config.filename_mapper(obj.local_path)
    return obj
end

---attach autocmd. While connecting with jupyterlab, will full sync
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
                    local syncable = self:safe_sync()
                    -- local connecting = self.client:is_connecting()
                    -- local line = api.nvim_buf_get_lines(self.bufnr, a.fn.line(".") - 1, a.fn.line("."), true)[1]
                    -- vim.notify(line.. "/" .. vim.inspect(connecting) .. "/" .. vim.inspect(syncable), nil, { id = "current line" })

                    if syncable then
                        self:partial_sync(start_row, old_end_row - 1, new_end_row - 1)
                    else
                        self:parse()
                    end
                end, function() end)
            end,
        })
    end

    self:parse()
    self._is_exist = nil
    if self:is_connecting() then
        self:open_or_reveal()
        self:activate()
        -- initial full sync
        self:full_sync()
    end
    require("neopyter.highlight").attach(self.bufnr, self.augroup)
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
            return self:is_exist()
        end
    end
    return false
end

function Notebook:safe_sync()
    if self:is_connecting() then
        if not self:is_open() then
            self:open_or_reveal()
        end
        return true
    end
    return false
end

function Notebook:get_parser()
    local ft = a.api.nvim_get_option_value("ft", { buf = self.bufnr })
    local lang = vim.treesitter.language.get_lang(ft) --[[@as string]]
    ---@type neopyter.Parser
    local parser = require("neopyter").parser[lang]
    return parser
end

function Notebook:parse()
    local lines = api.nvim_buf_get_lines(self.bufnr, 0, -1, true)
    local inotebook = self:get_parser():parse_notebook(lines)
    self.metadata = inotebook.metadata
    self.cells = inotebook.cells
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
    local val = self:_request("isFileExist")
    self._is_exist = val
    return val
end

--- whether corresponding `.ipynb` file opened in jupyter lab or not
---@return boolean
function Notebook:is_open()
    return self:_request("isFileOpen")
end

function Notebook:open()
    return self:_request("openFile")
end

function Notebook:open_or_reveal()
    return self:_request("openOrReveal")
end

---active notebook in jupyterlab
---@async
function Notebook:activate()
    return self:_request("activateNotebook")
end

---active cell
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

---get cursor pos
---@return integer # 0-index
---@return integer # 0-index
function Notebook:get_cursor_pos()
    -- local winid = utils.buf2winid(self.bufnr)
    --
    -- local pos = api.nvim_win_get_cursor(winid or 0)
    -- return pos[1], pos[2]
    return a.fn.line(".") - 1, a.fn.col(".") - 1
end

---@param pos integer[] (row, col) tuple representing the new position
function Notebook:set_cursor_pos(pos)
    local winid = utils.buf2winid(self.bufnr)
    ---@cast winid -nil
    vim.api.nvim_win_set_cursor(winid, pos)
end

---get current cell of cursor position, start from 1
---@return number #index of cell
---@return number #row of cursor in cell, 0-based
---@return number #col of cursor in cell, 0-based
function Notebook:get_cursor_cell_pos()
    local row, col = self:get_cursor_pos()
    for index, cell in ipairs(self.cells) do
        if cell.start_row <= row and row <= cell.end_row then
            if cell.no_separator then
                return index, row - cell.start_row - 1, col
            else
                return index, row - cell.start_row - 2, col
            end
        end
    end
    return 0, row, col
end

---get cell by pose
---@param row integer?
---@param col integer?
function Notebook:get_cell(row, col)
    if not row then
        row = a.fn.line(".") - 1
    end
    if not col then
        col = a.fn.col(".") - 1
    end
    for _, cell in ipairs(self.cells) do
        if cell.start_row <= row and row <= cell.end_row then
            return cell
        end
    end
end

---get cell source code
---@param index integer
---@return string?
function Notebook:get_cell_source(index)
    local cell = self.cells[index]
    if cell then
        return self:get_parser():parse_source(self.bufnr, cell)
    end
    return nil
end

function Notebook:full_sync()
    local cells = vim.iter(self.cells)
        :map(function(cell)
            local source = self:get_parser():parse_source(self.bufnr, cell)
            return {
                source = source,
                cell_type = cell.type,
            }
        end)
        :totable()
    self:_request("fullSync", cells)
end

---partial sync
---@param start_row integer
---@param old_end_row integer
---@param new_end_row integer
function Notebook:partial_sync(start_row, old_end_row, new_end_row)
    local old_cells = self.cells
    assert(old_cells ~= nil, "should already parse and exists cells")

    self:parse()
    local new_cells = self.cells

    local start_cell_index = -1
    local end_ocell_index = -1
    local real_start_row = start_row < old_end_row and start_row or old_end_row
    for i, cell in ipairs(old_cells) do
        if cell.start_row <= real_start_row and real_start_row <= cell.end_row then
            start_cell_index = i
        end
        if cell.start_row <= old_end_row and old_end_row <= cell.end_row then
            end_ocell_index = i
        end
    end
    local end_ncell_index = -1
    for i, cell in ipairs(new_cells) do
        if cell.start_row <= new_end_row and new_end_row <= cell.end_row then
            end_ncell_index = i
        end
    end
    -- vim.print(old_cells)
    -- vim.print(new_cells)
    --
    -- print(start_row, old_end_row, new_end_row, start_cell_index, end_ocell_index, end_ncell_index)
    local update_cells = vim.list_slice(new_cells, start_cell_index, end_ncell_index)
    local partial_cells = vim.iter(update_cells)
        :map(function(cell)
            local source = self:get_parser():parse_source(self.bufnr, cell)

            return {
                source = source,
                cell_type = cell.type,
            }
        end)
        :totable()

    self:_request("partialSync", start_cell_index - 1, end_ocell_index - 1, partial_cells)
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

---set notebook mode
---@param mode "command"|"edit"
function Notebook:set_mode(mode)
    return self:_request("setMode", mode)
end

---code completion
---@param options neopyter.CompletionParams
---@return neopyter.CompletionItem[]
function Notebook:complete(options)
    return self:_request("reconciliatorComplete", options)
    -- return self:_request("complete", options)
end

---code completion, but kernel complete only
---@param source string
---@param offset number
---@return {label: string, type: string, insertText:string, source: string}[]
function Notebook:kernel_complete(source, offset)
    return self:_request("kernelComplete", source, offset)
end

---@nodoc
Notebook = a.safe(Notebook, {
    "is_connecting",
})

return Notebook
