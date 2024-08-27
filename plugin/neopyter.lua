local jupyter = require("neopyter.jupyter")
local utils = require("neopyter.utils")
local a = require("plenary.async")

local cmds = {
    connect = {
        execute = function(address)
            local status = jupyter.jupyterlab:is_connecting()
            if status then
                utils.notify_warn("Jupyter lab is connecting, reset current and connect to " .. address)
                jupyter.jupyterlab:disconnect()
                jupyter.jupyterlab:connect(address)
            else
                jupyter.jupyterlab:connect(address)
            end
        end,
    },
    kernel = {
        complete = { "restart", "restartRunAll" },
        execute = function(mode)
            if mode == "restart" then
                jupyter.notebook:restart_kernel()
            elseif mode == "restartRunAll" then
                jupyter.notebook:restart_run_all()
            end
        end,
    },
    run = {
        complete = { "current", "allAbove", "allBelow", "all" },
        execute = function(mode)
            if mode == "current" then
                jupyter.notebook:run_selected_cell()
            elseif mode == "allAbove" then
                jupyter.notebook:run_all_above()
            elseif mode == "allBelow" then
                jupyter.notebook:run_all_below()
            elseif mode == "all" then
                jupyter.notebook:run_all()
            end
        end,
    },
    execute = {
        execute = function(command, args)
            if args ~= nil then
                local status, data = pcall(vim.json.decode, args)
                assert(status, data)
                args = data
            end
            jupyter.jupyterlab:execute_command(command, args)
        end,
    },
    disconnect = {
        execute = function()
            jupyter.jupyterlab:detach()
        end,
    },
    sync = {
        complete = { "current" },
        execute = function(file_or_current)
            if jupyter.notebook == nil then
                utils.notify_error("Current notebook not exist in local")
                return
            end
            if file_or_current == "current" then
                local path = jupyter.jupyterlab:current_ipynb()
                if path == nil or path == vim.NIL then
                    utils.notify_error("Current don't open/select any notebook in jupyterlab!")
                    return
                end
                file_or_current = path
            end
            local old_remote_path = jupyter.notebook.remote_path
            jupyter.notebook.remote_path = file_or_current
            if jupyter.notebook:is_exist() then
                jupyter.notebook:attach()
                if jupyter.notebook:is_open() then
                    jupyter.notebook:activate()
                else
                    jupyter.notebook:open_or_reveal()
                end
                jupyter.notebook:full_sync()
            else
                utils.notify_error(string.format("The file [%s] not exist in Jupyter lab", file_or_current))
                jupyter.notebook.remote_path = old_remote_path
                return
            end
        end,
    },
    status = {
        execute = function()
            vim.cmd("checkhealth neopyter")
        end,
    },
}

vim.api.nvim_create_user_command("Neopyter", function(opts)
    local cmd = cmds[opts.fargs[1]]
    if cmd ~= nil then
        table.remove(opts.fargs, 1)
        a.run(function()
            cmd.execute(unpack(opts.fargs))
        end, function() end)
    end
end, {
    desc = "Neopyter manager",
    nargs = "*",
    complete = function(_, line, _)
        local l = vim.split(line, "%s+")
        local n = #l - 2
        if n == 0 then
            return vim.tbl_filter(function(val)
                return vim.startswith(val, l[2])
            end, vim.tbl_keys(cmds))
        elseif n == 1 and cmds[l[2]] ~= nil then
            local cmd = cmds[l[2]]
            local condition = {}
            if type(cmd["complete"]) == "function" then
                condition = cmd.complete()
            elseif type(cmd["complete"]) == "table" then
                condition = cmd.complete --[[@as table]]
            end
            return vim.tbl_filter(function(val)
                return vim.startswith(val, l[3])
            end, condition)
        end
    end,
})
