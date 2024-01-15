local a = require("plenary.async")
local logger = require("neopyter.logger")

---wrap a class's member function,
---@param cls table
---@param ignored_methods? string[]
local function async_wrap(cls, ignored_methods)
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
                    end, function()
                        logger.log(string.format("Call api [%s] complete from main thread directly", key))
                    end)
                end
            end
        end
    end
    cls.__injected_methods = injected_methods
    logger.log(string.format("inject class end", vim.inspect(cls)))
    return cls
end
return async_wrap
