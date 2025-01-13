local utils = require("neopyter.utils")
local RpcClient = require("neopyter.rpc.baseclient")
local msgpack = require("neopyter.rpc.msgpack")
local logger = require("neopyter.logger")
local websocket = require("websocket")
local a = require("plenary.async")

---@class neopyter.WSServerClient:neopyter.RpcClient
---@field server? websocket.Server # nil means not connect
---@field single_connection? websocket.Connection
---@field private msg_count number
---@field private request_pool table<number, fun(...):any>
local WSServerClient = RpcClient:new({}) --[[@as neopyter.WSServerClient]]

---RpcClient constructor
---@param opt neopyter.NewRpcClientOption
---@return neopyter.WSServerClient
function WSServerClient:new(opt)
    local o = setmetatable(opt or {}, { __index = self }) --[[@as neopyter.WSServerClient]]
    o.msg_count = 0
    o.request_pool = {}
    return o
end

---comment
---@param address? string
---@param on_connected? fun() # call while connected
---@async
function WSServerClient:connect(address, on_connected)
    local restart_server = address ~= nil and self.address ~= address
    for _, fun in pairs(self.request_pool) do
        fun(false, "cancel")
    end
    self.request_pool = {}

    self.address = address or self.address
    assert(self.address, "Rpc client address is empty")
    if self.server then
        if not restart_server then
            return
        end
        self.server:close()
    end
    local host, port = utils.parse_address(self.address)
    self.server = websocket.Server:new({ host = host, port = port })
    local success, error = pcall(self.server.listen, self.server, {
        on_connect = function(connect)
            if self.single_connection ~= nil then
                utils.notify_warn("There are multiple lab extension connections at same time, please check if multiple tagbs are opened")
                connect:close()
                return
            end
            self.single_connection = connect
            self.single_connection:attach({
                on_text = function(text)
                    self:handle_response(text)
                end,
                on_disconnect = function()
                    self.single_connection = nil
                end,
            })
            if on_connected then
                on_connected()
                on_connected = nil
            end
        end,
        on_disconnect = function()
            self:disconnect()
        end,
    })
    if not success then
        ---@cast error -nil
        utils.notify_warn(error)
    end
end

---disconnect connect
function WSServerClient:disconnect()
    if self.single_connection then
        self.single_connection:close()
        self.single_connection = nil
        self.server:close()

        for _, fun in pairs(self.request_pool) do
            fun(false, "cancel")
        end
        self.request_pool = {}
    else
        logger("disconnect, but connection not exists")
    end
end

---check client is connecting
---@return boolean
function WSServerClient:is_connecting()
    return self.single_connection ~= nil
end

function WSServerClient:gen_id()
    self.msg_count = self.msg_count + 1
    return self.msg_count
end

---send request to server
---@param method string
---@param ... unknown # name
---@return unknown|nil
function WSServerClient:request(method, ...)
    if self.server == nil then
        utils.notify_error(string.format("RPC websocket server is stop, can't request [%s]", method))
        return
    elseif self.single_connection == nil then
        utils.notify_error(string.format("RPC websocket server is listening, but without client, can't request [%s]", method))
        return
    end
    local msgid = self:gen_id()
    local content = vim.mpack.encode({ 0, msgid, method, { ... } })
    assert(content, string.format("request [%s] error: encode failed", method))
    local status, res = a.wrap(function(callback)
        self.request_pool[msgid] = callback
        self.single_connection:send_text(vim.base64.encode(content))
        -- logger.log(string.format("msgid [%s] request [%s] send, content [%s]", msgid, method, content))
    end, 1)()
    logger.log(string.format("msgid [%s] finished: %s", msgid, vim.inspect(res)))

    if status then
        return res
    else
        if method == "getVersion" then
            utils.notify_error(
                string.format("jupyterlab extension is outdated, it is recommended to update with `pip install -U neopyter`", method, res)
            )
        else
            utils.notify_error(string.format("RPC request [%s] failed, with error: %s", method, res))
        end
    end
end

---handle rpc response
---@param data string
---@package
function WSServerClient:handle_response(data)
    local mpack = vim.base64.decode(data)
    local status, msg = pcall(vim.mpack.decode, mpack)
    if not status then
        logger.warn("parse mpack error, reset request pool")
        -- assert(status, string.format("%s: recevied data.length=%s, mpack.length=%s, msg=[%s]", vim.inspect(msg), #data, #mpack, mpack))
        utils.notify_error(msg)
        self:reset_request()
        return
    end
    if #msg == 4 and msg[1] == 1 then
        local msgid, error, result = msg[2], msg[3], msg[4]
        local callback = self.request_pool[msgid]
        self.request_pool[msgid] = nil
        logger.log(string.format("msgid [%s] response acceptd", msgid))
        assert(
            callback,
            string.format(
                "msg %s can't find callback: request_pool=%s, msg=%s",
                msgid,
                vim.inspect(vim.tbl_keys(self.request_pool)),
                vim.inspect(msg)
            )
        )
        if error == vim.NIL then
            callback(true, result)
        else
            callback(false, error)
        end
    else
        print("error!!")
        assert(false, "msgpack rpc response spec error, msg=" .. mpack)
    end
end

function WSServerClient:notify(event, ...) end

function WSServerClient:reset_request()
    for _, fun in pairs(self.request_pool) do
        fun(false, "reset")
    end
    self.request_pool = {}
end

return WSServerClient
