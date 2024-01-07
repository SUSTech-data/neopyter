local jupyter = require("neopyter.jupyter")
local JupyterLab = require("neopyter.jupyter.jupyterlab")
local utils = require("neopyter.utils")
local a = require("plenary.async")

---@class neopyter.Manager
local M = {}

---@param config neopyter.Option
function M.setup(config)
    local id = vim.api.nvim_create_augroup("neopyter_manager", { clear = true })
    utils.nvim_create_autocmd({ "BufWinEnter" }, {
        group = id,
        pattern = config.file_pattern,
        callback = function(event)
            if config.auto_attach and jupyter.jupyterlab == nil then
                jupyter.jupyterlab = JupyterLab:new({
                    address = config.remote_address,
                })
                jupyter.jupyterlab:attach()
            end
            if jupyter.jupyterlab then
                jupyter.jupyterlab:_on_bufwinenter(event.buf)
            end
        end,
    })
end

function M.manual_attach(address)
    if jupyter.jupyterlab ~= nil then
        utils.notify_warn("JupyterLab is exists, reconnection to " .. address)
        M.disconnect()
    end
    jupyter.jupyterlab = JupyterLab:new({
        address = address,
    })
    jupyter.jupyterlab:attach()
end

function M.disconnect()
    if jupyter.jupyterlab ~= nil then
        jupyter.jupyterlab:close()
        jupyter.jupyterlab = nil
        jupyter.notebook = nil
    end
end

return M
