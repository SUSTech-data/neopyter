local status, cmp = pcall(require, "cmp")
if status then
    cmp.register_source("neopyter", require("neopyter.cmp"))
    return
end
