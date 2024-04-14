local M = {}
local neopyter = require("neopyter")
local jupyter = require("neopyter.jupyter")

local a = require("plenary.async")

local health = {}

for key, value in pairs(vim.health) do
    if key[1] ~= "_" then
        health[key] = a.wrap(function(msg, callback)
            vim.schedule(function()
                value(msg)
                callback()
            end)
        end, 2)
    end
end

local function run_blocking(suspend_fn, ...)
    local resolved = false
    vim.schedule(function()
        a.run(suspend_fn, function(ee)
            resolved = true
        end)
    end)

    vim.wait(0x7FFFFFFF, function()
        return resolved
    end, 1000)
end

function M.check()
    run_blocking(function()
        local status = jupyter.jupyterlab:is_attached()
        if status then
            local nvim_plugin_ver = jupyter.jupyterlab:get_nvim_plugin_version()
            health.info(string.format("Neopyter@%s status: active", nvim_plugin_ver))
            local is_connecting = jupyter.jupyterlab.client:is_connecting()
            if is_connecting then
                health.info("Rpc server status: active")
                local jupyterlab_extension_ver = jupyter.jupyterlab:get_jupyterlab_extension_version()
                health.info(string.format("Jupyter lab extension version: %s", jupyterlab_extension_ver))
            else
                health.info("Rpc server status: inactive")
            end
            health.start("Jupyter lab")
            for _, notebook in pairs(jupyter.jupyterlab.notebook_map) do
                local select_mark = " "
                if jupyter.notebook == notebook then
                    select_mark = "*"
                end
                local msg = ""
                local nbconnect = notebook:is_connecting()
                if nbconnect then
                    msg = string.format("%s %s 💫 %s", select_mark, notebook.local_path, notebook.remote_path)
                else
                    msg = string.format("%s %s 💥", select_mark, notebook.local_path, notebook.remote_path)
                end
                health.info(msg)
            end
        else
            health.info(string.format("Neopyter status: inactive"))
        end
    end)
end

return M
