---@class neopyter.RpcClient
---@field address? string
---@field notify fun(event:string, ...:any):any
local RpcClient = {}

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
---@param address? string
---@async
function RpcClient:connect(address)
    assert(false, "not implement")
end

---disconnect connect
function RpcClient:disconnect()
    assert(false, "not implement")
end

---is rpc client connecting
function RpcClient:is_connecting()
    assert(false, "not implement")
end

---@see vim.rpcrequest
---@param method string
---@param ... unknown
function RpcClient:request(method, ...)
    assert(false, "not implement")
end

---@see vim.rpcnotify
---@param event string
---@param ... unknown
function RpcClient:notify(event, ...) end

return RpcClient
