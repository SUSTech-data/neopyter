local utils = require("neopyter.utils")

---@class neopyter.RpcClient
---@field address string
---@field channel_id number # 0 means not connect
local RpcClient = {
    address = "localhost:8889",
    channel_id = 0,
}

---@class neopyter.NewRpcClientOption
---@field address string

---create RpcCLient and connect
---@param o neopyter.NewRpcClientOption
---@return neopyter.RpcClient|nil
function RpcClient:create(o)
    self.__index = self
    setmetatable(o, self)

    local status, res = pcall(vim.fn.sockconnect, "tcp", o.address, {
        rpc = true,
    })
    if not status then
        utils.notify_error("RPC connect failed, with error: " .. res)
    else
        o.channel_id = res
        return o --[[@as neopyter.RpcClient]]
    end
end

---check client is connecting
---@return boolean
function RpcClient:is_connecting()
    return self.channel_id ~= 0
end

---send request to server
---@param method string
---@param ... unknown
---@return unknown|nil
function RpcClient:request(method, ...)
    if not self:is_connecting() then
        utils.notify_error("RPC channel not be initialized, please check jupyter lab server or restart connection")
        return
    end
    local status, res = pcall(vim.rpcrequest, self.channel_id, method, ...)

    if not status then
        utils.notify_error(string.format("RPC request [%s] failed, with error: %s", method, res))
    else
        return res
    end
end

function RpcClient:notify(event, ...)
    if not self:is_connecting() then
        utils.notify_error("RPC channel not be initialized, please check jupyter lab server or restart connection")
        return
    end
    local status, res = pcall(vim.notify, self.channel_id, event, ...)

    if not status then
        utils.notify_error("RPC notify failed, with error: " .. res)
    else
        return res
    end
end

function RpcClient:close()
    vim.fn.chanclose(self.channel_id)
end

return RpcClient
