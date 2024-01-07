local rpc = require("neopyter.rpc")
local Notebook = require("neopyter.jupyter.notebook")
local utils = require("neopyter.utils")
local a = require("plenary.async")
local api = a.api

---@class neopyter.JupyterOption
---@field auto_activate_file boolean

---@class neopyter.JupyterLab
---@field private client neopyter.RpcClient|nil
---@field notebook_map {[string]: neopyter.Notebook}
local JupyterLab = {}

---@class neopyter.NewJupyterLabOption
---@field address string

---create RpcClient and connect
---@param opts neopyter.NewJupyterLabOption
---@return neopyter.JupyterLab
function JupyterLab:new(opts)
    local o = {}
    self.__index = self
    setmetatable(o, self)

    local config = require("neopyter").config
    local RpcClient
    if config.rpc_client == "block" then
        RpcClient = rpc.BlockRpcClient
    else
        RpcClient = rpc.AsyncRpcClient
    end
    o.client = RpcClient:new({
        address = opts.address,
    })
    self.notebook_map = {}
    return o
end

function JupyterLab:attach()
    self.client:connect()
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
    local file_path = api.nvim_buf_get_name(buf)
    local notebook = self:get_notebok(file_path, buf)
    local jupyter = require("neopyter.jupyter")
    jupyter.notebook = notebook

    if notebook:is_exist() then
        notebook:activate()
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
