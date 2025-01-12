local a = require("plenary.async")

local async = {
    run = a.run,

    ---run function in async context, until timeout or complete
    ---@param suspend_fn fun()
    ---@param callback fun(success, ret_val)
    ---@param timeout number?
    run_blocking = function(suspend_fn, callback, timeout)
        local resolved = false
        local msg
        vim.schedule(function()
            a.run(suspend_fn, function(data)
                msg = data
                resolved = true
            end)
        end)

        local success = vim.wait(timeout or 10000, function()
            return resolved
        end, 100)
        callback(success, msg)
    end,
}

async.uv = vim.uv
async.api = a.uv

async.api = vim.api
async.api = a.api

async.fn = vim.fn
async.fn = setmetatable({}, {
    __index = function(_, k)
        return function(...)
            -- if we are in a fast event await the scheduler
            if vim.in_fast_event() then
                require("plenary.async.util").scheduler()
            end
            return vim.fn[k](...)
        end
    end,
})

async.defer_fn = vim.defer_fn

async.defer_fn = function(fn, timeout)
    vim.defer_fn(function()
        a.run(function()
            fn()
        end, function() end)
    end, timeout)
end

async.health = vim.health

async.health = setmetatable({}, {
    __index = function(_, k)
        return function(...)
            -- if we are in a fast event await the scheduler
            if vim.in_fast_event() then
                require("plenary.async.util").scheduler()
            end
            return vim.health[k](...)
        end
    end,
})

---Wrap a class's member function,
---User could call `lua =require("neopyter.jupyter").notebook:run_selected_cell()` in main thread directly
---@param cls table
---@param ignored_methods? string[]
function async.safe(cls, ignored_methods)
    local logger = require("neopyter.logger")
    ignored_methods = ignored_methods or {}
    table.insert(ignored_methods, "new")
    local function is_ignored(key)
        for _, val in ipairs(ignored_methods) do
            if val == key then
                return true
            end
        end
        return false
    end
    logger.log(string.format("inject class %s start", vim.inspect(cls)))
    local injected_methods = {}
    for key, value in pairs(cls) do
        if not key:match("^_%w.+$") and not is_ignored(key) and type(value) == "function" then
            logger.log(string.format("inject method [%s]", key))
            table.insert(injected_methods, key)
            cls[key] = function(...)
                local thread = coroutine.running()
                if thread ~= nil then
                    return value(...)
                else
                    local params = { ... }
                    logger.log(string.format("Call api [%s] from main thread directly", key))
                    return a.run(function()
                        return value(unpack(params))
                    end, function(result)
                        local utils = require("neopyter.utils")
                        ---WARN:Only when the user directly calls the API from the main thread, e.g. autocmd, keymap,
                        ---     programmatic calls should be wrapped with `require("plenary.async").run(...)`
                        utils.notify_info(string.format("Call api [%s] complete: %s", key, result))
                        logger.log(string.format("Call api [%s] complete from main thread directly: %s", key, result))
                    end)
                end
            end
        end
    end
    cls.__injected_methods = injected_methods
    logger.log(string.format("inject class end", vim.inspect(cls)))
    return cls
end
return async
