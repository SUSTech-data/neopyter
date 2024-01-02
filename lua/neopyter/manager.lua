local options = require("neopyter.options")
local jupyter = require("neopyter.jupyter")
local JupyterLab = require("neopyter.jupyter.jupyterlab")

---@class neopyter.Manager
local M = {}

function M.create_autocmd()
    local id = vim.api.nvim_create_augroup("neopyter_manager", { clear = true })
    vim.api.nvim_create_autocmd({ "BufWinEnter" }, {
        group = id,
        pattern = options.file_pattern,
        callback = function(event)
            if options.auto_attach and jupyter.jupyterlab == nil then
                jupyter.jupyterlab = JupyterLab:create({
                    address = options.remote_address,
                })
            end
            if jupyter.jupyterlab then
                jupyter.jupyterlab:_on_bufwinenter(event.buf)
            end
        end,
    })
end

return M
