local Path = require("plenary.path")
local a = require("plenary.async")
local M = {}

---
function M.first_upper(str)
    return (str:gsub("^%l", string.upper))
end

---emit info notify via vim.notify
---@param msg string
function M.notify_info(msg)
    vim.schedule(function()
        vim.notify(msg, vim.log.levels.INFO, {
            title = "Neopyter",
        })
    end)
end

---emit debug notify via vim.notify
---@param msg string
function M.notify_debug(msg)
    vim.schedule(function()
        vim.notify(msg, vim.log.levels.DEBUG, {
            title = "Neopyter",
        })
    end)
end

---emit warning notify via vim.notify
---@param msg string
function M.notify_warn(msg)
    vim.schedule(function()
        vim.notify(msg, vim.log.levels.WARN, {
            title = "Neopyter",
        })
    end)
end

---emit error notify via vim.notify
---@param msg string
function M.notify_error(msg)
    vim.schedule(function()
        vim.notify(msg, vim.log.levels.ERROR, {
            title = "Neopyter",
        })
    end)
end

---get relative path
---@param parent_path string
---@param file_path string
---@return string
function M.relative_to(file_path, parent_path)
    local path = Path:new(file_path)
    return path:make_relative(parent_path)
end

function M.is_absolute(file_path)
    return Path:new(file_path):is_absolute()
end

---same with nvim.api.nvim_create_autocmd
---@param event any
---@param opts any
---@see vim.api.nvim_create_autocmd
function M.nvim_create_autocmd(event, opts)
    if opts ~= nil and type(opts.callback) == "function" then
        local old_callback = opts.callback
        opts.callback = function(...)
            local args = { ... }
            a.run(function()
                old_callback(unpack(args))
            end, function() end)
        end
    end
    vim.api.nvim_create_autocmd(event, opts)
end

---@class neopyter.ParseOption
---@field line_magic boolean|nil
---@field content_annotated_cell_types string[]|nil

---parse lines
---@param lines string[]
---@param filetype? string default python
---@return neopyter.Cell[]
function M.parse_content(lines, filetype)
    local option = require("neopyter").config.parse_option
    filetype = filetype or "python"
    ---@type neopyter.Cell []
    local cells = {}
    for i, line in ipairs(lines) do
        if vim.startswith(line, "# %%") then
            local cell_magic, magic_param = line:match("^# %%%%(%w+)(.*)")
            if cell_magic ~= nil then
                table.insert(cells, {
                    lines = { line },
                    start_line = i,
                    cell_type = "code",
                    cell_magic = "%%" .. cell_magic .. magic_param,
                })
            else
                local titleornil, cell_type = line:match("^# %%%%(.*)%[(%w+)%]")
                if titleornil == nil then
                    titleornil = line:match("^# %%%%(.*)$")
                end
                if titleornil ~= nil then
                    titleornil = vim.trim(titleornil)
                    if titleornil == "" then
                        titleornil = nil
                    end
                end

                if cell_type == "md" then
                    cell_type = "markdown"
                end

                table.insert(cells, {
                    lines = { line },
                    start_line = i,
                    cell_type = cell_type or "code",
                    title = titleornil,
                })
            end
        elseif #cells == 0 then
            table.insert(cells, {
                lines = { line },
                start_line = i,
                cell_type = "code",
                no_separator = true,
            })
        else
            table.insert(cells[#cells].lines, line)
        end
    end
    local function concat_code(code_lines, i, j)
        code_lines = vim.tbl_map(function(line)
            if option.line_magic then
                local line_magic = line:match("# (%%%w+.*)")
                if line_magic ~= nil then
                    return line_magic
                end
            end
            return line
        end, code_lines)
        return table.concat(code_lines, "\n", i, j)
    end

    for i, cell in ipairs(cells) do
        if cell then
            cell.end_line = cell.start_line + #cell.lines
        end

        if cell.cell_magic ~= nil then
            cell.source = cell.cell_magic .. "\n" .. table.concat(cell.lines, "\n", 2)
        elseif cell.cell_type == "markdown" or cell.cell_type == "raw" then
            cell.source = table.concat(cell.lines, "\n", 2)
            if filetype == "python" then
                local comment_source = vim.trim(cell.source):match('^"""\n(.*)\n"""$')
                if comment_source ~= nil then
                    cell.source = comment_source
                end
                cell.source = cell.source:gsub('\\"\\"\\"', '"""')
            end
        elseif cell.no_separator == true then
            cell.source = concat_code(cell.lines)
        else
            cell.source = concat_code(cell.lines, 2)
        end
    end
    return cells
end

return M
