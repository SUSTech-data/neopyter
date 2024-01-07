local manager = require("neopyter.manager")
local jupyter = require("neopyter.jupyter")
local a = require("plenary.async")

vim.api.nvim_create_user_command("Neopyter", function(opts)
    local function run(cmds)
        if #cmds < 1 then
            vim.ui.select({ "connect", "disconnect" }, { prompt = "Neopyter" }, function(item)
                if item then
                    table.insert(cmds, item)
                    run(cmds)
                end
            end)
        elseif #cmds == 1 then
            if cmds[1] == "connect" then
                vim.ui.input({
                    prompt = "Neopyter",
                }, function(input)
                    if input ~= nil and #input > 0 then
                        table.insert(cmds, input)
                        run(cmds)
                    end
                end)
            elseif cmds[1] == "run" then
                vim.ui.select({ "current", "allAbove", "allBelow" }, { prompt = "Neopyter" }, function(item)
                    if item then
                        table.insert(cmds, item)
                        run(cmds)
                    end
                end)
            elseif cmds[1] == "disconnect" then
                manager.disconnect()
            end
        elseif #cmds == 2 then
            if cmds[1] == "connect" then
                a.run(function()
                    manager.manual_attach(cmds[2])
                end, function() end)
            elseif cmds[1] == "run" then
                a.run(function()
                    if cmds[2] == "current" then
                        jupyter.notebook:run_selected_cell()
                    elseif cmds[2] == "allAbove" then
                        jupyter.notebook:run_all_above()
                    elseif cmds[3] == "allBelow" then
                        jupyter.notebook:run_all_below()
                    end
                end, function() end)
            end
        end
    end
    run(opts.fargs)
end, {
    desc = "Neopyter manager",
    nargs = "*",
    complete = function(_, line, _)
        return { "connect", "disconnect", "run" }
    end,
})
