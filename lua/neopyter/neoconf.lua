local neoconf = require("neoconf")
local M = {}

local __filepath__ = debug.getinfo(1).source:sub(2)
local __project_root__ = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(__filepath__)))

function M.reload_neoconf_settings()
    local settings = neoconf.get("neopyter", {})
    local neopyter = require("neopyter")
    neopyter.config = vim.tbl_deep_extend("force", neopyter.config, settings)
end

function M.setup()
    require("neoconf.plugins").register({
        name = "neopyter",
        on_schema = function(schema)
            local schema_path = vim.fs.joinpath(__project_root__, "schema", "neoconf.json")
            schema:set("neopyter", {
                ["$ref"] = vim.uri_from_fname(schema_path),
            })
        end,
        on_update = function()
            M.reload_neoconf_settings()
        end,
    })
    M.reload_neoconf_settings()
end

return M
