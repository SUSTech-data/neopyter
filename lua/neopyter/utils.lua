local Path = require("plenary.path")
local a = require("neopyter.async")
local api = a.api
local M = {}

local source = debug.getinfo(1).source
-- local __dirname__ = source:match("@(.*/)") or source:match("@(.*\\)")

local __root__ = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h:h")
local is_windows = vim.loop.os_uname().version:match("Windows")

if is_windows then
    __root__ = __root__:gsub("/", "\\")
end

---get plugin root
---@return Path
function M.get_plugin_path()
    return Path:new(__root__)
end

---@param buf number
---@return Path
function M.get_buf_path(buf)
    local file_path = api.nvim_buf_get_name(buf)
    file_path = vim.fs.normalize(file_path)
    if is_windows then
        file_path = file_path:gsub("/", "\\")
    end
    return Path:new(file_path)
end

---
function M.first_upper(str)
    return (str:gsub("^%l", string.upper))
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

---get relative path
---@param parent_path string
---@param file_path string
---@return string
function M.relative_to(file_path, parent_path)
    local path = Path:new(file_path)
    return path:make_relative(parent_path)
end

function M.buf2winid(bufnr)
    for _, win in ipairs(api.nvim_list_wins()) do
        if api.nvim_win_get_buf(win) == bufnr then
            return win
        end
    end
    return nil
end

---@param address string
---@return string host
---@return number port
function M.parse_address(address)
    local host, port = address:match("^(.-):(%d+)$")
    return host, tonumber(port)--[[@as number]]
end

-- ======= Code mostly based on Saghen/blink.cmp ===

local function _validate(path, spec)
    if vim.fn.has("nvim-0.11") == 0 then
        return vim.validate(spec)
    end
    for key, key_spec in pairs(spec) do
        local message = type(key_spec[3]) == "string" and key_spec[3] or nil --[[@as string?]]
        local optional = type(key_spec[3]) == "boolean" and key_spec[3] or nil --[[@as boolean?]]
        vim.validate(string.format("config `%s.%s`", path, key), key_spec[1], key_spec[2], optional, message)
    end
end

--- @param tbl table The table to validate
--- @param source table The original table that we're validating against
--- @see vim.validate
function M.validate_config(path, tbl, source)
    -- validate
    local _, err = pcall(_validate, path, tbl)
    if err then
        error(path .. "." .. err)
    end

    -- check for erroneous fields
    for k, _ in pairs(source) do
        if tbl[k] == nil then
            error(string.format("unexpected field `%s.%s` found in configuration", path, k))
        end
    end
end

---@generic T
---@param fn T callable
---@param timeout integer? # milliseconds
---@return T
function M.throttle(fn, timeout, ...)
    timeout = timeout or 20
    ---@cast timeout -nil
    local timer = assert(a.uv.new_timer())
    local args = { ... }
    return function()
        if timer:is_active() then
            return
        end
        timer:start(timeout, 0, function()
            a.run(function()
                fn(unpack(args))
            end, function() end)
        end)
    end
end

return M
