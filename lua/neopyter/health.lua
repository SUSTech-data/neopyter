local M = {}
local neopyter = require("neopyter")
local jupyter = require("neopyter.jupyter")

local a = require("neopyter.async")
local health = a.health

function M.check()
    if not jupyter.jupyterlab then
        health.error(string.format("Please setup neopyter first"))
        return
    end

    a.run_blocking(function()
        health.start("neopyter: config")
        health.info(vim.inspect(neopyter.config))
        local status = jupyter.jupyterlab:is_attached()

        health.start("neopyter: treesitter")
        local languages = { "python", "r", "markdown" }
        vim.iter(languages):each(function(lang)
            if vim.treesitter.language.add(lang) then
                health.ok(string.format("parser: %s parser is installed", lang))
            else
                health.warn(string.format("parser: %s parser is not installed, please install via `:TSInstall %s`", lang, lang))
            end
        end)

        health.start("neopyter: version")
        local nvim_plugin_ver = jupyter.jupyterlab:get_nvim_plugin_version()
        health.info(string.format("os platform of neovim: %s", vim.uv.os_uname().sysname))
        health.info(string.format("neovim version: %s", vim.version()))
        if status then
            health.info(string.format("neovim plugin(neopyter@%s) status: active", nvim_plugin_ver))
            local is_connecting = jupyter.jupyterlab:is_connecting()
            if is_connecting then
                local jupyterlab_extension_ver = jupyter.jupyterlab:get_jupyterlab_extension_version()
                health.info(string.format("jupyter lab extension(neopyter@%s): active", jupyterlab_extension_ver))
                if nvim_plugin_ver ~= jupyterlab_extension_ver then
                    health.warn(
                        string.format(
                            "The version of JupyterLab extension(neopyter==%s) is older then neovim plugin(neopyter==%s), please update via `pip install -U neopyter`",
                            jupyterlab_extension_ver,
                            nvim_plugin_ver
                        )
                    )
                end
            else
                health.info("jupyter lab extension: don't connect")
            end

            health.start("neopyter: status")
            health.info("attach: tracking with neopyter\nconnect: synchronizing with jupyter lab\n")
            local msg = string.format("  %-30s %-10s %-10s %s", "file", "attach", "connect", "remote_path")
            for _, notebook in pairs(jupyter.jupyterlab.notebook_map) do
                local select_mark = " "
                if jupyter.notebook == notebook then
                    select_mark = "*"
                end
                local nbconnect = notebook:is_connecting()

                if nbconnect then
                    msg = msg
                        .. "\n"
                        .. string.format(
                            "%s %-30s %-10s %-10s %s",
                            select_mark,
                            notebook.local_path,
                            notebook:is_attached(),
                            nbconnect,
                            notebook.remote_path
                        )
                else
                    msg = msg .. "\n" .. string.format("%s %-30s %-10s false", select_mark, notebook.local_path, notebook:is_attached(), nbconnect)
                end
            end
            health.info(msg)
        else
            health.info(string.format("neovim plugin(neopyter@%s) status: inactive", nvim_plugin_ver))
        end
    end, function(success)
        if not success then
            health.error(string.format("return code:%s", code))
            health.error("Call async function without return in a long time!!")
        end
    end)
end

return M
