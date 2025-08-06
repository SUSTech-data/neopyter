local ts = require("neopyter.treesitter")

---@class neopyter.InjectionOption
---@field enable boolean

local injection = {}

---@nodoc
function injection.setup()
    ts.load_query("injections", "python")
    ts.load_query("injections", "r")
end

return injection
