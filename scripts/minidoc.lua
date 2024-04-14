local minidoc = require("mini.doc")

if _G.MiniDoc == nil then
    minidoc.setup({})
end

minidoc.generate({ "lua/neopyter.lua", "lua/neopyter/jupyter/jupyterlab.lua", "lua/neopyter/jupyter/notebook.lua" }, nil, nil)
