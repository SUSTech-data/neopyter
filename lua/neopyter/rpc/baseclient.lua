---@class neopyter.RpcClient
---@field host string
---@field request fun(method:string, ...:unknown[]):any
---@field notify fun(event:string, ...:unknown[]):any
local RpcClient = {
    address = "localhost:8889",
}

---@class neopyter.NewRpcClientOption
---@field address? string

---RpcClient constructor
---@param o neopyter.NewRpcClientOption
---@return neopyter.RpcClient
function RpcClient:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o --[[@as neopyter.RpcClient]]
end

---start connect
---@async
function RpcClient:connect() end

return RpcClient
