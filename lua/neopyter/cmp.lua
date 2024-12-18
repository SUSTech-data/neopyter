local jupyter = require("neopyter.jupyter")
local utils = require("neopyter.utils")
local a = require("plenary.async")
local cmp = require("cmp")
local source = {}

local jupyter_complete_spec_types = {
    ["magic"] = "Magic",
    ["path"] = "Path",
    ["dict key"] = "Dictkey",
    ["instance"] = "Instance",
    ["statement"] = "Statement",
}

source.new = function()
    local self = setmetatable({}, { __index = source })
    return self
end

---Return whether this source is available in the current context or not (optional).
---@return boolean
function source:is_available()
    return jupyter.notebook ~= nil and jupyter.jupyterlab.client:is_connecting()
end

function source:get_debug_name()
    return "neopyter"
end

---Return trigger characters for triggering completion (optional).
function source:get_trigger_characters()
    return { "%%", ".", "/", "%" }
end

---Invoke completion (required).
---@param params cmp.SourceCompletionApiParams
---@param callback fun(response: lsp.CompletionResponse|nil)
function source:complete(params, callback)
    local notebook = jupyter.notebook
    if notebook == nil or params.context.bufnr ~= notebook.bufnr then
        callback()
        return
    end

    a.run(function()
        if not jupyter.notebook:is_connecting() then
            callback({})
            return
        end

        local code = params.context.cursor_before_line
        local offset = math.min(params.offset, #code)
        notebook:partial_sync(params.context.cursor.row, params.context.cursor.row, params.context.cursor.row)
        local cell_idx = notebook:get_cursor_cell_pos()

        local items = jupyter.notebook:complete({
            source = code,
            offset = offset - 1,
            cellIndex = cell_idx - 1,
            params = params,
        })
        items = vim.iter(items)
            :filter(function(item)
                if params.option.completers then
                    ---@type string[]
                    local completers = params.option.completers
                    return vim.tbl_contains(completers, item.source)
                end
                return true
            end)
            :map(function(item)
                local type = item.type
                local kind = utils.first_upper(type)

                if jupyter_complete_spec_types[type] ~= nil then
                    return {
                        label = item.label,
                        -- Text
                        kind = 1,
                        insertText = item.insertText,
                        cmp = {
                            kind_hl_group = "CmpItemKind" .. jupyter_complete_spec_types[type],
                            kind_text = kind,
                        },
                        document = item.document,
                    }
                else
                    return {
                        label = item.label,
                        -- Text
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

---Resolve completion item (optional). This is called right before the completion is about to be displayed.
---Useful for setting the text shown in the documentation window (`completion_item.documentation`).
---@param completion_item lsp.CompletionItem
---@param callback fun(completion_item: lsp.CompletionItem|nil)
function source:resolve(completion_item, callback)
    callback(completion_item)
end

---Executed after the item was selected.
---@param completion_item lsp.CompletionItem
---@param callback fun(completion_item: lsp.CompletionItem|nil)
function source:execute(completion_item, callback)
    callback(completion_item)
end

return source
