---@class neopyter.MsgpackDecoder
---@field buffer string
---@field private unpacker any
local Decoder = {}

---Decoder constructor
---@param o any
---@return neopyter.MsgpackDecoder
function Decoder:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    o.buffer = ""
    o.unpacker = vim.mpack.Unpacker()
    return o
end

function Decoder:feed(data)
    self.buffer = self.buffer .. data
end

function Decoder:next()
    if #self.buffer == 0 then
        return nil
    end
    local obj, pos = self.unpacker(self.buffer)
    self.buffer = self.buffer:sub(pos)
    return obj
end

return {
    Decoder = Decoder,
}
