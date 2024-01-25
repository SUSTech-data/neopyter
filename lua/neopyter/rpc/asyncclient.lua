local utils = require("neopyter.utils")
local RpcClient = require("neopyter.rpc.baseclient")
local msgpack = require("neopyter.rpc.msgpack")
local logger = require("neopyter.logger")
local a = require("plenary.async")

---@class neopyter.AsyncRpcClient:neopyter.RpcClient
---@field tcp_client? uv_tcp_t # nil means not connect
---@field private msg_count number
---@field private request_pool table<number, fun(...):any>
---@field private decoder neopyter.MsgpackDecoder
local AsyncRpcClient = RpcClient:new({}) --[[@as neopyter.AsyncRpcClient]]

---RpcClient constructor
---@param o neopyter.NewRpcClientOption
---@return neopyter.AsyncRpcClient
function AsyncRpcClient:new(o)
    o = o or {} --[[@as neopyter.AsyncRpcClient]]
    setmetatable(o, self)
    self.__index = self

    o.msg_count = 0
    o.request_pool = {}
    o.decoder = msgpack.Decoder:new()
    return o
end

---@package
---@param address string
local function parse_address(address)
    local host, port = address:match("^(.-):(%d+)$")
    return host, tonumber(port)
end

---comment
---@param address? string
---@async
function AsyncRpcClient:connect(address)
    self.address = address or self.address
    assert(self.tcp_client == nil, "current connection exists, can't call connect, please disconnect first")
    assert(self.address, "Rpc client address is empty")
    self.tcp_client = vim.loop.new_tcp()
    local host, port = parse_address(self.address)
    local err = a.uv.tcp_connect(self.tcp_client, host, port)
    if err ~= nil then
        utils.notify_error(string.format("Connect rpc server [%s] failed", self.address))
        self.tcp_client = nil
    else
        self.tcp_client:read_start(function(e, data)
            if e ~= nil or data == nil then
                utils.notify_error(string.format("Rpc connection was broken: %s", vim.inspect(e)))
                utils.notify_error(vim.inspect(e))
                for _, callback in ipairs(self.request_pool) do
                    callback(false, e)
                end
                self:close()
            else
                self:handle_response(data)
            end
        end)
    end
end

---disconnect connect
function AsyncRpcClient:disconnect()
    self.tcp_client:close()
    self.tcp_client = nil
end

---check client is connecting
---@return boolean
function AsyncRpcClient:is_connecting()
    return self.tcp_client ~= nil
end

function AsyncRpcClient:gen_id()
    self.msg_count = self.msg_count + 1
    return self.msg_count
end

---send request to server
---@param method string
---@param ... unknown # name
---@return unknown|nil
function AsyncRpcClient:request(method, ...)
    if not self:is_connecting() then
        utils.notify_error(string.format("RPC tcp client is disconnected, can't request [%s]", method))
        return
    end
    local msgid = self:gen_id()
    local content = vim.mpack.encode({ 0, msgid, method, { ... } })
    assert(content, string.format("request [%s] error: encode failed", method))
    local status, res = a.wrap(function(callback)
        self.request_pool[msgid] = callback
        self.tcp_client:write(content)
        logger.log(string.format("msgid [%s] request [%s] sended", msgid, method))
    end, 1)()
    logger.log(string.format("msgid [%s] finished", msgid))

    if status then
        return res
    else
        utils.notify_error(string.format("RPC request [%s] failed, with error: %s", method, res))
    end
end

---handle rpc response
---@param data string
---@package
function AsyncRpcClient:handle_response(data)
    self.decoder:feed(data)
    while true do
        local msg = self.decoder:next()
        if msg == nil then
            break
        end
        -- logger.log(vim.inspect(msg))
        if #msg == 4 and msg[1] == 1 then
            local msgid, error, result = msg[2], msg[3], msg[4]
            local callback = self.request_pool[msgid]
            self.request_pool[msgid] = nil
            logger.log(string.format("msgid [%s] response acceptd", msgid))
            assert(
                callback,
                string.format("msg %s can't find callback: request_pool=%s", msgid, vim.inspect(self.request_pool))
            )
            if error == vim.NIL then
                callback(true, result)
            else
                callback(false, error)
            end
        else
            assert(false, "msgpack rpc response spec error, msg=" .. data)
        end
    end
end

function AsyncRpcClient:notify(event, ...) end

---close tcp
---@async
function AsyncRpcClient:close()
    if self.tcp_client then
        self.tcp_client:close(function() end)
    end
end

return AsyncRpcClient
