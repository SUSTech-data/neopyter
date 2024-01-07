---@class neopyter.Notebook
---@field private client neopyter.RpcClient
---@field bufnr number
---@field local_path string realative path
---@field private cellslines string[][]
---@field private active_cell_index number
local Notebook = {
    bufnr = -1,
    cellslines = {},
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
    local obj = setmetatable(o, self) --[[@as neopyter.Notebook]]
    obj:_attach_event()
    obj:parse()
    obj:full_sync()
    return obj
end

function Notebook:remote_path()
    local config = require("neopyter").config
    return config.filename_mapper(self.local_path)
end

function Notebook:_attach_event()
    local augroup = vim.api.nvim_create_augroup(string.format("jupynium_buf_%d", self.bufnr), { clear = true })
    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
        buffer = self.bufnr,
        callback = function()
            local row, col = self:get_cursor_pos()
            local line_count = 0
            for index, cell_lines in ipairs(self.cellslines) do
                line_count = line_count + #cell_lines
                if line_count >= row then
                    local active_index = index - 1
                    if active_index ~= self.active_cell_index then
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
            self:save()
        end,
        group = augroup,
    })

    vim.api.nvim_create_autocmd({ "BufUnload" }, {
        buffer = self.bufnr,
        callback = function()
            -- TODO:close notebook, and select previous?
        end,
        group = augroup,
    })

    vim.api.nvim_buf_attach(self.bufnr, false, {
        on_lines = function(_, _, _, start_row, old_end_row, new_end_row, _)
            -- TODO:particl update
            self:parse()
            self:full_sync()
        end,
    })
end

function Notebook:_request(method, ...)
    return self.client:request(method, self:remote_path(), ...)
end

---is exist corresponding notebok in remote server
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
    local cells = {}
    for i, cell_lines in ipairs(self.cellslines) do
        if type(cell_lines[1]) == "string" and cell_lines[1]:match("# %%") then
            cells[i] = {
                source = table.concat(cell_lines, "\n", 2),
                cell_type = "code",
            }
        else
            cells[i] = {
                source = table.concat(cell_lines, "\n"),
                cell_type = "code",
            }
        end
    end
    self:_request("setCellNum", #cells)
    self:_request("syncCells", 0, cells)
end

function Notebook:save()
    self:_request("save")
end

function Notebook:parse()
    local lines = vim.api.nvim_buf_get_lines(self.bufnr, 0, -1, true)
    local cellslines = {}
    for i, line in ipairs(lines) do
        if line:find("# %%") == 1 or #cellslines == 0 then
            table.insert(cellslines, {})
        end
        table.insert(cellslines[#cellslines], line)
    end
    self.cellslines = cellslines
end

return Notebook
