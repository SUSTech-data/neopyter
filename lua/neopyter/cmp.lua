local jupyter = require("neopyter.jupyter")
local utils = require("neopyter.utils")
local a = require("plenary.async")
local cmp = require("cmp")
local source = {}

source.new = function()
    local self = setmetatable({}, { __index = source })
    return self
end

---Return whether this source is available in the current context or not (optional).
---@return boolean
function source:is_available()
    return jupyter.jupyterlab:is_connecting() and jupyter.notebook ~= nil and jupyter.notebook:is_attached()
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
    a.run(function()
        local code = params.context.cursor_before_line
        local offset = math.min(params.offset, #code)
        local items = jupyter.notebook:kernel_complete(code, offset)
        items = vim.tbl_map(function(item)
            local type = item.type
            local kind = utils.first_upper(type)
            local jupyter_complete_types = { "magic", "path" }
            if vim.tbl_contains(jupyter_complete_types, type) then
                return {
                    label = item.label,
                    -- Text
                    kind = 1,
                    insertText = item.insertText,
                    cmp = {
                        kind_hl_group = "CmpItemKind" .. kind,
                        kind_text = kind,
                    },
                }
            else
                return {
                    label = item.label,
                    -- Text
                    kind = cmp.lsp.CompletionItemKind[kind],
                    insertText = item.insertText,
                }
            end
        end, items)
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
