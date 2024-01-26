local utils = require("neopyter.utils")
local RpcClient = require("neopyter.rpc.baseclient")

---@class neopyter.BlockRpcClient:neopyter.RpcClient
---@field channel_id number # 0 means not connect
local BlockRpcClient = RpcClient:new({
    channel_id = 0,
}) --[[@as neopyter.BlockRpcClient]]

-- ---create RpcClient and connect
-- ---@param o neopyter.NewRpcClientOption
-- ---@return neopyter.BlockRpcClient
-- function BlockRpcClient:new(o)
--     o = o or {}
--     setmetatable(o, self)
--     self.__index = self
--     return o
-- end

function BlockRpcClient:connect()
    local status, res = pcall(vim.fn.sockconnect, "tcp", self.address, {
        rpc = true,
    })
    if not status then
        utils.notify_error("RPC connect failed, with error: " .. res)
    else
        self.channel_id = res
    end
end

function BlockRpcClient:disconnect()
    vim.fn.chanclose(self.channel_id)
    self.channel_id = 0
end

---check client is connecting
---@return boolean
function BlockRpcClient:is_connecting()
    return self.channel_id ~= 0
end

---send request to server
---@param method string
---@param ... unknown # name
---@return unknown|nil
function BlockRpcClient:request(method, ...)
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

function BlockRpcClient:notify(event, ...)
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

return BlockRpcClient
