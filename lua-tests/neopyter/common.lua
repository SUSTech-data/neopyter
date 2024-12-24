local M = {}

---load content to temporary buffer
---@param content elem_or_list<string>
---@return number
function M.load_buffer(content)
    if type(content) == "string" then
        content = vim.split(content, "\n", { trimempty = true })
        ---@cast content string[]
    end
    --
    local buf = vim.api.nvim_create_buf(true, false)

    vim.api.nvim_buf_set_lines(buf, 0, 0, true, content)
    vim.api.nvim_buf_set_lines(buf, #content, #content + 1, true, {})
    vim.bo[buf].filetype = "python"
    return buf
end

---@param content elem_or_list<string>
---@param query_name string
---@return integer
---@return vim.treesitter.Query
---@return TSTree
function M.to_treesitter(content, query_name)
    local buf = M.load_buffer(content)
    local parser = vim.treesitter.get_parser(buf, "python")
    ---@cast parser -nil
    local query = vim.treesitter.query.get("python", query_name)
    local tree = parser:parse(true)
    ---@cast query -nil
    return buf, query, tree[1]
end

---load file to buffer
---@param file string
function M.load_file(file)
    local buf = vim.fn.bufadd(file)
    vim.fn.bufload(buf)
    return buf
end

function M.get_buf_conent(buf)
    local count = vim.api.nvim_buf_line_count(buf)
    return table.concat(vim.api.nvim_buf_get_lines(buf, 0, count, true), "\n")
end


return M
