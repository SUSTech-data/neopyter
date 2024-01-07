local manager = require("neopyter.manager")

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
            elseif cmds[1] == "disconnect" then
                manager.disconnect()
            end
        elseif #cmds == 2 then
            if cmds[1] == "connect" then
                manager.manual_attach(cmds[2])
            end
        end
    end
    run(opts.fargs)
end, {
    desc = "Neopyter manager",
    nargs = "*",
    complete = function(_, line, _)
        return { "connect", "disconnect" }
    end,
})
