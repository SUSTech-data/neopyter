local jupyter = require("neopyter.jupyter")
local a = require("neopyter.async")
local Completer = require("neopyter.completer")
local cmp = require("cmp")

---@class neopyter.CmpCompleter
---@field completer neopyter.Completer
local neopyter = {
    completer = Completer.new(),
}

neopyter.new = function()
    local self = setmetatable({}, { __index = neopyter })
    return self
end

---Return whether this source is available in the current context or not (optional).
---@return boolean
function neopyter.is_available()
    return neopyter.completer:is_available()
end

function neopyter:get_debug_name()
    return neopyter.completer:get_name()
end

---Return trigger characters for triggering completion (optional).
function neopyter:get_trigger_characters()
    return self.completer:get_trigger_characters()
end

---Invoke completion (required).
---@param params cmp.SourceCompletionApiParams
---@param callback fun(response: lsp.CompletionResponse|nil)
function neopyter:complete(params, callback)
    a.run(function()
        local notebook = jupyter.notebook
        if self:is_available() then
            callback()
            return
        end
        ---@cast notebook -nil

        local code = params.context.cursor_before_line
        local offset = math.min(params.offset, #code)

        local cell_idx, line, column = notebook:get_cursor_cell_pos()

        local items = neopyter.completer:get_completions({
            source = code,
            offset = offset,
            cellIndex = cell_idx - 1,
            params = params,
            trigger = Completer.CompletionTriggerKind.Invoked,
            line = line,
            column = column,
        })
        items = vim.iter(items)
            :map(function(item)
                local kind = item.type
                if vim.tbl_contains(Completer.jupyter_spec_kind, kind) then
                    return {
                        label = item.label,
                        -- Text
                        kind = 1,
                        insertText = item.insertText,
                        document = item.document,
                        cmp = {
                            kind_hl_group = "CmpItemKind" .. kind,
                            kind_text = kind,
                        },
                    }
                else
                    return {
                        label = item.label,
                        kind = cmp.lsp.CompletionItemKind[kind],
                        insertText = item.insertText,
                        document = item.document,
                    }
                end
            end)
            :totable()
        callback(items)
    end, function() end)
end

return neopyter
