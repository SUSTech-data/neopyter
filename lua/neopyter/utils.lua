local Path = require("plenary.path")
local a = require("plenary.async")
local api = a.api
local M = {}

local source = debug.getinfo(1).source
local __dirname__ = source:match("@(.*/)") or source:match("@(.*\\)")

---get plugin root
---@return Path
function M.get_plugin_path()
    return Path:new(__dirname__):parent():parent()
end

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
    a.api.nvim_create_autocmd(event, opts)
end

---parse lines
---@param lines string[]
---@param filetype? string default python
---@return neopyter.Cell[]
function M.parse_content(lines, filetype)
    local option = require("neopyter").config.parser
    ---@cast option -nil

    filetype = filetype or "python"
    ---@type neopyter.Cell []
    local cells = {}
    for i, line in ipairs(lines) do
        if vim.startswith(line, "# %%") then
            local cell_magic, magic_param = line:match("^# %%%%(%w+)(.*)")
            if cell_magic ~= nil then
                -- table.insert(cells, {
                --     lines = { line },
                --     start_line = i,
                --     cell_type = "code",
                --     cell_magic = "%%" .. cell_magic .. magic_param,
                -- })
                cells[#cells].cell_magic = "%%" .. cell_magic .. magic_param
                table.insert(cells[#cells].lines, line:sub(2))
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
            if vim.startswith(line, "# !") or vim.startswith(line, "# %") then
                table.insert(cells[#cells].lines, line:sub(3))
            else
                table.insert(cells[#cells].lines, line)
            end
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

    for _, cell in ipairs(cells) do
        if cell then
            cell.end_line = cell.start_line + #cell.lines
        end

        if cell.cell_magic ~= nil then
            local source = table.concat(cell.lines, "\n", 3)
            cell.source = cell.cell_magic .. "\n" .. source
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
        if option.trim_whitespace then
            cell.source = vim.trim(cell.source)
        end
    end
    return cells
end

function M.read_file(path)
    local err, fd = a.uv.fs_open(path, "r", 438)
    assert(not err, err)
    local err1, stat = a.uv.fs_fstat(fd)
    assert(not err1, err1)
    local err2, data = a.uv.fs_read(fd, stat.size, 0)
    assert(not err2, err2)
    local err3 = a.uv.fs_close(fd)
    assert(not err3, err3)
    return data
end

function M.buf2winid(bufnr)
    for _, win in ipairs(api.nvim_list_wins()) do
        if api.nvim_win_get_buf(win) == bufnr then
            return win
        end
    end
    return nil
end

---@param address string
---@return string host
---@return number port
function M.parse_address(address)
    local host, port = address:match("^(.-):(%d+)$")
    return host, tonumber(port)--[[@as number]]
end

-- ======= Code mostly based on Saghen/blink.cmp ===

local function _validate(path, spec)
    if vim.fn.has("nvim-0.11") == 0 then
        return vim.validate(spec)
    end
    for key, key_spec in pairs(spec) do
        local message = type(key_spec[3]) == "string" and key_spec[3] or nil --[[@as string?]]
        local optional = type(key_spec[3]) == "boolean" and key_spec[3] or nil --[[@as boolean?]]
        vim.validate(string.format("config `%s.%s`", path, key), key_spec[1], key_spec[2], optional, message)
    end
end

--- @param tbl table The table to validate
--- @param source table The original table that we're validating against
--- @see vim.validate
function M.validate_config(path, tbl, source)
    -- validate
    local _, err = pcall(_validate, path, tbl)
    if err then
        error(path .. "." .. err)
    end

    -- check for erroneous fields
    for k, _ in pairs(source) do
        if tbl[k] == nil then
            error(string.format("unexpected field `%s.%s` found in configuration", path, k))
        end
    end
end

--- ===== end ============

return M
