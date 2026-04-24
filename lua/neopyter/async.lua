local a = require("vim._async")



--- @brief Neopyter's async module, which provides async functions and utilities for Neopyter.
--- Which is built on top of native async support (`vim._async`) in Neovim, and provides a more convenient API for users to use async functions in Neopyter.
--- The API of neopyter are mostly async, and users could call them in a sync context, neopyter will automatically wrap them in an async context, so
--- that users could call them directly without worrying about async context, but the order of execution is not guaranteed, if you want to guarantee
--- the order of execution, you should use `require("neopyter.async").run(...)` to run them in an async context.
---
--- Example1: Call API in sync context, but the order of execution is not guaranteed
--- ```lua
--- vim.defer_fn(function()
---     -- non-async context, API response may be unordered
---     current_notebook:run_selected_cell()
---     current_notebook:run_all_above()
---     current_notebook:run_all_below()
--- end, 0)
--- Example2: Call API in async context, the order of execution is guaranteed
--- require("neopyter.async").run(function()
---     -- async context, so which will call and return in order
---     current_notebook:run_selected_cell()
---     current_notebook:run_all_above()
---     current_notebook:run_all_below()
--- end)
--- ```

local async = {}

---Creates an async function with a callback style function.
---@param func function: A callback style function to be converted. The last argument must be the callback.
---@param argc number: The number of arguments of func. Must be included.
---@return async fun: Returns an async function
function async.wrap(func, argc)
    ---@async
    return function(...)
        return a.await(argc, func, ...)
    end
end

async.scheduler = async.wrap(vim.schedule, 1)

function async.safe_async()
    if vim.in_fast_event() then
        async.scheduler()
    end
end

---Use this to either run a future concurrently and then do something else
---or use it to run a future with a callback in a non async context
---@param func async fun(): ...:any
---@param on_finish? fun(err: string?, ...:any)
function async.run(func, on_finish)
    if on_finish == nil then
        on_finish = function(err)
            if err then
                error(err)
            end
        end
    end
    a.run(func, on_finish)
end

---run function in async context, until timeout or complete
---@param suspend_fn fun()
---@param on_finish? fun(err: string?, ...:any)
---@param timeout number?
function async.run_blocking(suspend_fn, on_finish, timeout)
    if not on_finish then
        on_finish = function(err)
            if err then
                error(err)
            end
        end
    end

    local resolved = false
    local err
    local data
    vim.schedule(function()
        async.run(suspend_fn, function(e, ...)
            if e == nil then
                data = { ... }
            else
                err = e
            end
            resolved = true
        end)
    end)

    local success = vim.wait(timeout or 10000, function()
        return resolved
    end, 100)
    if not success then
        on_finish("Async function timed out", unpack(data or {}))
    else
        on_finish(err, unpack(data or {}))
    end
end

async.fn = vim.fn
async.fn = setmetatable({}, {
    __index = function(_, k)
        return function(...)
            -- if we are in a fast event await the scheduler
            async.safe_async()
            return vim.fn[k](...)
        end
    end,
})

async.uv = vim.uv
async.uv = {}

local function add(name, argc, custom)
    local success, ret = pcall(async.wrap, custom or vim.uv[name], argc)

    if not success then
        error("Failed to add function with name " .. name)
    end

    async.uv[name] = ret
end


add("close", 4) -- close a handle

-- filesystem operations
add("fs_open", 4)
add("fs_read", 4)
add("fs_close", 2)
add("fs_unlink", 2)
add("fs_write", 4)
add("fs_mkdir", 3)
add("fs_mkdtemp", 2)
-- 'fs_mkstemp',
add("fs_rmdir", 2)
add("fs_scandir", 2)
add("fs_stat", 2)
add("fs_fstat", 2)
add("fs_lstat", 2)
add("fs_rename", 3)
add("fs_fsync", 2)
add("fs_fdatasync", 2)
add("fs_ftruncate", 3)
add("fs_sendfile", 5)
add("fs_access", 3)
add("fs_chmod", 3)
add("fs_fchmod", 3)
add("fs_utime", 4)
add("fs_futime", 4)
-- 'fs_lutime',
add("fs_link", 3)
add("fs_symlink", 4)
add("fs_readlink", 2)
add("fs_realpath", 2)
add("fs_chown", 4)
add("fs_fchown", 4)
-- 'fs_lchown',
add("fs_copyfile", 4)
add("fs_opendir", 3, function(path, entries, callback)
    return uv.fs_opendir(path, callback, entries)
end)
add("fs_readdir", 2)
add("fs_closedir", 2)
-- 'fs_statfs',

-- stream
add("shutdown", 2)
add("listen", 3)
-- add('read_start', 2) -- do not do this one, the callback is made multiple times
add("write", 3)
add("write2", 4)
add("shutdown", 2)

-- tcp
add("tcp_connect", 4)
-- 'tcp_close_reset',

-- pipe
add("pipe_connect", 3)

-- udp
add("udp_send", 5)
add("udp_recv_start", 2)

-- fs event (wip make into async await event)
-- fs poll event (wip make into async await event)

-- dns
add("getaddrinfo", 4)
add("getnameinfo", 2)


async.api = vim.api
async.api = setmetatable({}, {
    __index = function(_, k)
        return function(...)
            -- if we are in a fast event await the scheduler
            async.safe_async()
            return vim.api[k](...)
        end
    end,
})

---same with nvim.api.nvim_create_autocmd
---@param event any
---@param opts any
---@see vim.api.nvim_create_autocmd
async.api.nvim_create_autocmd = function(event, opts)
    async.safe_async()
    if opts ~= nil and vim.is_callable(opts.callback) then
        local callback = opts.callback
        opts.callback = function(...)
            local args = { ... }
            async.run(function()
                callback(unpack(args))
            end, function(err)
                if err then
                    error(err)
                end
            end)
        end
    end
    return vim.api.nvim_create_autocmd(event, opts)
end


async.defer_fn = vim.defer_fn

async.defer_fn = function(fn, timeout)
    vim.defer_fn(function()
        async.run(function()
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
                async.scheduler()
            end
            return vim.health[k](...)
        end
    end,
})

---Wrap a class's member function,
---User could call `lua =require("neopyter.jupyter").notebook:run_selected_cell()` in main thread directly
---@param cls table
---@param ignored_methods? string[]
function async.safe_wrap(cls, ignored_methods)
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
                    return async.run(function()
                        return value(unpack(params))
                    end, function(result)
                        local utils = require("neopyter.utils")
                        ---WARN:Only when the user directly calls the API from the main thread, e.g. autocmd, keymap,
                        ---     programmatic calls should be wrapped with `require("neopyter.async").run(...)`
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
