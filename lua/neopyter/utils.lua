local Path = require("plenary.path")
local a = require("plenary.async")
local M = {}

function M.string_begins_with(str, start)
    if str == nil then
        return false
    end
    return start == "" or str:sub(1, #start) == start
end

function M.string_ends_with(str, ending)
    if str == nil then
        return false
    end
    return ending == "" or str:sub(-#ending) == ending
end

function M.wildcard_to_regex(pattern)
    local reg = pattern:gsub("([^%w])", "%%%1"):gsub("%%%*", ".*")
    if not M.string_begins_with(reg, ".*") then
        reg = "^" .. reg
    end
    if not M.string_ends_with(reg, ".*") then
        reg = reg .. "$"
    end
    return reg
end

function M.string_wildcard_match(str, pattern)
    return str:match(M.wildcard_to_regex(pattern))
end

function M.list_wildcard_match(str, patterns)
    for _, pattern in ipairs(patterns) do
        if M.string_wildcard_match(str, pattern) ~= nil then
            return true
        end
    end
    return false
end

function M.remove_duplicates(list)
    local hash = {}
    local res = {}
    for _, v in ipairs(list) do
        if not hash[v] then
            res[#res + 1] = v
            hash[v] = true
        end
    end
    return res
end

function M.table_concat(t1, t2)
    for i = 1, #t2 do
        t1[#t1 + 1] = t2[i]
    end
    return t1
end

---emit info notify via vim.notify
---@param msg string
function M.notify_info(msg)
    vim.schedule(function()
        vim.notify(msg, vim.log.levels.INFO, {
            title = "Neopyter",
        })
    end)
end

---emit debug notify via vim.notify
---@param msg string
function M.notify_debug(msg)
    vim.schedule(function()
        vim.notify(msg, vim.log.levels.DEBUG, {
            title = "Neopyter",
        })
    end)
end

---emit warning notify via vim.notify
---@param msg string
function M.notify_warn(msg)
    vim.schedule(function()
        vim.notify(msg, vim.log.levels.WARN, {
            title = "Neopyter",
        })
    end)
end

---emit error notify via vim.notify
---@param msg string
function M.notify_error(msg)
    vim.schedule(function()
        vim.notify(msg, vim.log.levels.ERROR, {
            title = "Neopyter",
        })
    end)
end

---get realtive path
---@param parent_path string
---@param file_path string
---@return string
function M.relative_to(file_path, parent_path)
    local path = Path:new(file_path)
    return path:make_relative(parent_path)
end

function M.is_absolute(file_path)
    return Path:new(file_path):is_absolute()
end

---same with nvim.api.nvim_create_autocmd
---@param event any
---@param opts any
---@see vim.api.nvim_create_autocmd
function M.nvim_create_autocmd(event, opts)
    if opts ~= nil and type(opts.callback) == "function" then
        local old_callback = opts.callback
        opts.callback = function(...)
            local args = { ... }
            a.run(function()
                old_callback(unpack(args))
            end, function() end)
        end
    end
    vim.api.nvim_create_autocmd(event, opts)
end

return M
