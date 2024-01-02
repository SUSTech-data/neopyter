local RpcClient = require("neopyter.jupyter.rpc_client")
local Notebook = require("neopyter.jupyter.notebook")
local options = require("neopyter.options")
local utils = require("neopyter.utils")

---@class neopyter.JupyterLab
---@field private client neopyter.RpcClient|nil
---@field notebook_map {[string]: neopyter.Notebook}
local JupyterLab = {}

---@class neopyter.NewJupyterLabOption
---@field address string

---create RpcCLient and connect
---@param opts neopyter.NewJupyterLabOption
---@return neopyter.JupyterLab
function JupyterLab:create(opts)
    local o = {}
    self.__index = self
    setmetatable(o, self)

    o.client = RpcClient:create({
        address = opts.address,
    })
    self.notebook_map = {}
    return o
end

---get or create notebook from *.ju.* path (global), if not exists, create with buf
---@param ju_path string
---@param buf? number
function JupyterLab:get_notebok(ju_path, buf)
    if utils.is_absolute(ju_path) then
        ju_path = utils.relative_to(ju_path, vim.fn.getcwd())
    end

    local notebook = self.notebook_map[ju_path]
    if notebook == nil and buf ~= nil then
        notebook = Notebook:create({
            client = self.client,
            bufnr = buf,
            local_path = ju_path,
        })
        self.notebook_map[ju_path] = notebook
    end
    return notebook
end

---called when `BufWinEnter`
---@param buf number
function JupyterLab:_on_bufwinenter(buf)
    local file_path = vim.api.nvim_buf_get_name(buf)
    local notebook = self:get_notebok(file_path, buf)

    if notebook:is_exist() then
        if options.jupyter.auto_open_file then
            -- notebook:open()
        end
        if options.jupyter.auto_activate_file then
            notebook:activate()
        end
    elseif options.jupyter.auto_new_file then
        notebook:create_new()
    end
end

---simple echo
---@param msg string
---@return string|nil
function JupyterLab:echo(msg)
    return self.client:request("echo", msg)
end

---@class neopyter.NewUntitledOption
---@field path? string
---@field type? `notebook`|`file`
--
---create new notebook, and selected it
---@param ops? neopyter.NewUntitledOption
---@return unknown|nil
function JupyterLab:new_untitled(ops)
    ops = ops or { path = "", type = "notebook" }
    return self.client:request("new_untitled", ops)
end

function JupyterLab:close()
    return self.client:close()
end

return JupyterLab
