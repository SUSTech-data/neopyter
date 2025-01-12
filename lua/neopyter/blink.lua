local jupyter = require("neopyter.jupyter")
local Completer = require("neopyter.completer")
local a = require("neopyter.async")

--- @brief Neopyter provide a global `jupyterlab` represent remote `JupyterLab` instance,
--- which provides some RPC-based API to control remote `JupyterLab` instance.
--- You could obtain `neopyter.Notebook` instance to control notebook via `JupyterLab`
---
--- Example:
---
--- ```lua
--- require("neopyter.async").run(function()
---     -- async context
---     local lab = require("neopyter.jupyter")
---     local notebook = lab:get_notebook(0) -- Get notebook via buffer
---     notebook:scroll_to_item(0) -- Scroll to first cell
--- end)
---
--- ```
--- NOTICE: Most API is need a async context, but neopyter provide a wrapped async context
--- automatically

---@class blink.cmp.Source
---@field completer neopyter.Completer
local neopyter = {}

function neopyter.new(opts)
    local self = setmetatable({}, { __index = neopyter })
    self.completer = Completer.new(opts)

    return self
end

function neopyter:get_trigger_characters()
    return self.completer:get_trigger_characters()
end

function neopyter:enabled()
    return self.completer:is_available()
end

function neopyter:get_completions(context, callback)
    -- we use libuv, but the rest of the library expects to be synchronous
    callback = vim.schedule_wrap(callback)
    local opts = self.opts
    local CompletionItemKind = require("blink.cmp.types").CompletionItemKind
    a.run(function()
        local notebook = jupyter.notebook
        if not notebook then
            callback()
            return
        end
        local col = context.cursor[2]
        local text = context.line:sub(1, col)

        local cell_idx, line, column = notebook:get_cursor_cell_pos()
        local items = self.completer:get_completions({
            source = text,
            offset = col,
            cellIndex = cell_idx - 1,
            params = context,
            line = line,
            column = column,
            trigger = Completer.CompletionTriggerKind.Invoked,
        })

        items = vim.iter(items)
            :map(function(item)
                ---@cast item neopyter.CompletionItem
                local kind
                if vim.tbl_contains(Completer.jupyter_spec_kind, item.type) then
                    kind = 1
                else
                    kind = CompletionItemKind[kind]
                end

                ---@type blink.cmp.CompletionItem
                ---@diagnostic disable-next-line: missing-fields
                return {
                    -- source_id = "neopyter",
                    -- source_name = "Neopyter",
                    insertText = item.insertText,
                    kind = kind,
                    label = item.label,
                    documentation = {
                        value = "",
                    },
                }
            end)
            :totable()

        callback({
            is_incomplete_forward = false,
            is_incomplete_backward = false,
            items = items,
            context = context,
        })
    end, function() end)
end

return neopyter
