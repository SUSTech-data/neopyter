local rpc = require("neopyter.rpc")
local Notebook = require("neopyter.jupyter.notebook")
local utils = require("neopyter.utils")
local async_wrap = require("neopyter.asyncwrap")
local a = require("plenary.async")
local api = a.api

---@class neopyter.JupyterOption
---@field auto_activate_file boolean

---@class neopyter.JupyterLab
---@field client neopyter.RpcClient
---@field private augroup number
---@field notebook_map {[string]: neopyter.Notebook}
local JupyterLab = {}

---@class neopyter.NewJupyterLabOption
---@field address? string

---create RpcClient and connect
---@param opts neopyter.NewJupyterLabOption
---@return neopyter.JupyterLab
function JupyterLab:new(opts)
    local o = {} --[[@as neopyter.JupyterLab]]
    setmetatable(o, self)
    self.__index = self

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

---attach autocmd and server
---@param address? string address of neopyter server
function JupyterLab:attach(address)
    self.client:connect(address)
    if not self.client:is_connecting() then
        return false
    end
    local config = require("neopyter").config
    self.augroup = api.nvim_create_augroup("neopyter-jupyterlab", { clear = true })
    assert(self.augroup ~= nil, "autogroup failed")
    utils.nvim_create_autocmd({ "BufWinEnter" }, {
        group = self.augroup,
        pattern = config.file_pattern,
        callback = function(event)
            self:_on_bufwinenter(event.buf)
        end,
    })
    utils.nvim_create_autocmd({ "BufUnload" }, {
        group = self.augroup,
        pattern = config.file_pattern,
        callback = function(event)
            self:_on_buf_unloaded(event.buf)
        end,
    })
    api.nvim_exec_autocmds("BufWinEnter", {
        group = self.augroup,
        pattern = config.file_pattern,
    })
end

function JupyterLab:detach()
    for _, notebook in pairs(self.notebook_map) do
        if notebook:is_attached() then
            notebook:detach()
        end
    end
    self.notebook_map = {}
    self.augroup = nil
    return self.client:disconnect()
end

---get status of jupyterlab
---@return boolean
function JupyterLab:is_connecting()
    local status = self.client:is_connecting()
    assert(status == (self.augroup ~= nil), "autogroup status shold keep same with client")
    return status
end

function JupyterLab:_get_buf_local_path(buf)
    local file_path = api.nvim_buf_get_name(buf)

    if utils.is_absolute(file_path) then
        file_path = utils.relative_to(file_path, vim.fn.getcwd())
    end
    return file_path
end

---if not exists, create with buf
---@param buf number
function JupyterLab:_on_bufwinenter(buf)
    local file_path = JupyterLab:_get_buf_local_path(buf)
    local notebook = self.notebook_map[file_path]
    if notebook == nil then
        notebook = Notebook:new({
            client = self.client,
            bufnr = buf,
            local_path = file_path,
        })
        self.notebook_map[file_path] = notebook
        if notebook:is_exist() then
            notebook:attach()
            notebook:open_or_reveal()
            notebook:activate()
        end
    end
    local jupyter = require("neopyter.jupyter")
    jupyter.notebook = notebook
    if notebook:is_attached() then
        notebook:open_or_reveal()
        notebook:activate()
    end
end

function JupyterLab:_on_buf_unloaded(buf)
    local file_path = self:_get_buf_local_path(buf)
    local notebook = self.notebook_map[file_path]
    if notebook == nil then
        return
    end
    notebook:detach()
    self.notebook_map[file_path] = nil
end

---simple echo
---@param msg string
---@return string|nil
function JupyterLab:echo(msg)
    return self.client:request("echo", msg)
end

---execute jupyter lab's commands
---@param command string
---@param args? table<string, any>
---@return nil
---[View documents](https://jupyterlab.readthedocs.io/en/stable/user/commands.html#commands-list)
function JupyterLab:execute_command(command, args)
    return self.client:request("executeCommand", command, args)
end

---@class neopyter.NewUntitledOption
---@field path? string
---@field type? `notebook`|`file`
--
---create new notebook, and selected it
function JupyterLab:createNew(ipynb_path, widget_name, kernel)
    return self.client:request("createNew", ipynb_path, widget_name, kernel)
end

---get current notebook of jupyter lab
function JupyterLab:current_ipynb()
    return self.client:request("getCurrentNotebook", ops)
end

JupyterLab = async_wrap(JupyterLab, { "is_connecting" })
return JupyterLab
