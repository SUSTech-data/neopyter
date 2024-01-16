local M = {}
local neopyter = require("neopyter")
local jupyter = require("neopyter.jupyter")

function M.check()
    local status = jupyter.jupyterlab:status()
    vim.health.report_info(string.format("Neopyter status: %s", status))
    if status ~= "idle" then
        vim.health.report_start("Jupyter lab")
        for _, notebook in pairs(jupyter.jupyterlab.notebook_map) do
            local select_mark = " "
            if jupyter.notebook == notebook then
                select_mark = "*"
            end
            if notebook:is_attached() then
                vim.health.report_info(
                    string.format(
                        "%s %s ❤️s %s",
                        select_mark,
                        notebook.local_path,
                        notebook.remote_path
                    )
                )
            else
                vim.health.report_info(
                    string.format(
                        "%s %s 💔",
                        select_mark,
                        notebook.local_path,
                        notebook.remote_path
                    )
                )
            end
        end
    end
end

return M
