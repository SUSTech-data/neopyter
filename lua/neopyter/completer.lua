local utils = require("neopyter.utils")
local jupyter = require("neopyter.jupyter")
local a = require("neopyter.async")
local api = a.api

---@class neopyter.CompleterOption
---@field source?  ("CompletionProvider:kernel"|"CompletionProvider:context"|"LSP"|string)[] default is all

---@enum neopyter.CompletionTriggerKind
local CompletionTriggerKind = {
    Invoked = 1,
    TriggerCharacter = 2,
    TriggerForIncompleteCompletions = 3,
}

local jupyter_spec_kind = {
    "Magic",
    "Path",
    "Dictkey",
    "Instance",
    "Statement",
}

---@enum neopyter.CompletionItemKind
local CompletionItemKind = {
    "Text",
    "Method",
    "Function",
    "Constructor",
    "Field",
    "Variable",
    "Class",
    "Interface",
    "Module",
    "Property",
    "Unit",
    "Value",
    "Enum",
    "Keyword",
    "Snippet",
    "Color",
    "File",
    "Reference",
    "Folder",
    "EnumMember",
    "Constant",
    "Struct",
    "Event",
    "Operator",
    "TypeParameter",

    --- jupyter only
    "Magic",
    "Path",
    "Dictkey",
    "Instance",
    "Statement",
}

---@class neopyter.CompletionParams {
---@field source string  code before cursor
---@field cellIndex number the cell index of cursor
---@field offset number offset of cursor in source
---@field trigger neopyter.CompletionTriggerKind
---@field line number The cursor line number.
---@field column number The cursor column number.

---@class neopyter.CompletionItem
---@field label string
---@field type string
---@field insertText string
--- Completion source of `JupyterLab` , one of:
--- - `CompletionProvider:kernel` jupynium provider
--- - `CompletionProvider:context`
--- - `LSP` if jupyterlab-lsp is installed
--- - others if some lab extension installed
---@field source string

local jupyter_complete_spec_types = {
    ["magic"] = "Magic",
    ["path"] = "Path",
    ["dict key"] = "Dictkey",
    ["instance"] = "Instance",
    ["statement"] = "Statement",
}

---@nodoc
---@class neopyter.Completer
---@field opts neopyter.CompleterOption
local Completer = {
    CompletionTriggerKind = CompletionTriggerKind,
    CompletionItemKind = CompletionItemKind,
    jupyter_spec_kind = jupyter_spec_kind,
}

---completer constructor
---@nodoc
---@param opts neopyter.CompleterOption?
function Completer.new(opts)
    local self = setmetatable({}, { __index = Completer })
    self:update_opts(opts)
    return self
end

---@nodoc
function Completer:get_name()
    return "neopyter"
end

---update opts
---@nodoc
---@param opts neopyter.CompleterOption
function Completer:update_opts(opts)
    self.opts = vim.tbl_deep_extend("force", self.opts or {}, opts or {})
end

---@nodoc
function Completer:get_trigger_characters()
    return { "%", ".", "%%", "/" }
end

---@nodoc
function Completer:is_available()
    return jupyter.notebook ~= nil and jupyter.notebook:is_connecting() and jupyter.notebook.bufnr == api.nvim_get_current_buf()
end

---convert complete item
---@nodoc
---@param item neopyter.CompletionItem
---@return neopyter.CompletionItem
function Completer:convert_complete_item(item)
    local ret = {}
    for key, value in pairs(item) do
        if value ~= vim.NIL then
            ret[key] = value
        end
    end
    ret["type"] = ret["type"] or "Text"
    ret["type"] = utils.first_upper(ret["type"])
    ret["type"] = jupyter_complete_spec_types[ret["type"]] or ret["type"]
    return ret
end

---@nodoc
---@param params neopyter.CompletionParams
---@return neopyter.CompletionItem[]
function Completer:get_completions(params)
    local notebook = jupyter.notebook
    ---@cast notebook -nil
    local items = notebook:complete(params)
    items = vim.iter(items):map(function(item)
        return self:convert_complete_item(item)
    end)

    if self.opts.source then
        items = items:filter(function(item)
            ---@cast item neopyter.CompletionItem
            return vim.tbl_contains(self.opts.source, item.source)
        end)
    end
    return items:totable()
end

return Completer
