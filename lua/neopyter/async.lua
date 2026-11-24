local a = vim.async or require("vim._async")



--- @brief Neopyter's async module, which provides async functions and utilities for Neopyter.
--- Which is built on top of native async support in Neovim, and provides a more convenient API for users to use async functions in Neopyter.
--- The API of neopyter are mostly async, and must be called within an `async.run` context to guarantee the order of execution.
---
--- Example: Call API in async context
--- ```lua
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
    if vim.async then
        -- Keep background work independent of the calling task.
        a.run(func):detach():on_complete(on_finish)
    else
        a.run(func, on_finish)
    end
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

return async
