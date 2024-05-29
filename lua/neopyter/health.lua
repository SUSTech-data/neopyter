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

    local success, code = vim.wait(10000, function()
        return resolved
    end, 100)
    if not success then
        vim.inspect(jupyter.jupyterlab.client:disconnect())
        vim.health.error(string.format("return code:%s", code))
        vim.health.error("Call async function without return in a long time!!")
    end
end

function M.check()
    run_blocking(function()
        health.start("neopyter: config")
        health.info(vim.inspect(neopyter.config))
        local status = jupyter.jupyterlab:is_attached()
        health.start("neopyter: version")
        local nvim_plugin_ver = jupyter.jupyterlab:get_nvim_plugin_version()
        if status then
            health.info(string.format("neovim plugin(neopyter@%s) status: active", nvim_plugin_ver))
            local is_connecting = jupyter.jupyterlab.client:is_connecting()
            if is_connecting then
                local jupyterlab_extension_ver = jupyter.jupyterlab:get_jupyterlab_extension_version()
                health.info(string.format("jupyter lab extension(neopyter@%s): active", jupyterlab_extension_ver))
            else
                health.info(string.format("jupyter lab extension: don't connect", jupyterlab_extension_ver))
            end
            health.start("neopyter: status")
            health.info("attach=ready, connect=syncing\n")
            health.info(string.format("  %-30s %-10s %-10s %s", "file", "attach", "connect", "remote_path"))
            for _, notebook in pairs(jupyter.jupyterlab.notebook_map) do
                local select_mark = " "
                if jupyter.notebook == notebook then
                    select_mark = "*"
                end
                local msg = ""
                local nbconnect = notebook:is_connecting()

                if nbconnect then
                    msg = string.format(
                        "%s %-30s %-10s %-10s %s",
                        select_mark,
                        notebook.local_path,
                        notebook:is_attached(),
                        nbconnect,
                        notebook.remote_path
                    )
                else
                    msg = string.format("%s %-30s %-10s false", select_mark, notebook.local_path, notebook:is_attached(), nbconnect)
                end

                health.info(msg)
            end
        else
            health.info(string.format("neovim plugin(neopyter@%s) status: inactive", nvim_plugin_ver))
        end
    end)
end

return M
