local M = {}
local neopyter = require("neopyter")
local jupyter = require("neopyter.jupyter")

function M.check()
    local status = jupyter.jupyterlab:status()
    vim.health.report_info(string.format("Neopyter status: %s", status))
    if status ~= "idle" then
        vim.health.report_start("Jupyter lab")
        for _, notebook in pairs(jupyter.jupyterlab.notebook_map) do
            local mark = " "
            if jupyter.notebook == notebook then
                mark = "*"
            end
            vim.health.report_info(string.format("%s %s <-> %s", mark, notebook.local_path, notebook.remote_path))
        end
    end
end

return M
