local Notebook = require("neopyter.jupyter.notebook")
local utils = require("neopyter.utils")
local async_wrap = require("neopyter.asyncwrap")
local a = require("plenary.async")
local Path = require("plenary.path")
local api = a.api

local __filepath__ = debug.getinfo(1).source:sub(2)

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
    local o = {}
    setmetatable(o, self)
    self.__index = self

    local config = require("neopyter").config
    local RpcClient
    if config["rpc_client"] ~= nil then
        vim.notify(
            "`rpc_client` is deprecated, please reference to https://github.com/SUSTech-data/neopyter/issues/4",
            vim.log.levels.ERROR,
            { title = "Neopyter" }
        )
    end
    if config.mode == "direct" then
        RpcClient = require("neopyter.rpc.wsserverclient")
    else
        RpcClient = require("neopyter.rpc.asyncclient")
    end
    o.client = RpcClient:new({
        address = opts.address,
    })
    self.notebook_map = {}
    return o
end

---attach autocmd
function JupyterLab:attach()
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
end

---get status of jupyterlab
---@return boolean
function JupyterLab:is_attached()
    -- local status = self.client:is_connecting()
    -- assert(status == (self.augroup ~= nil), "autogroup status shold keep same with client")
    return self.augroup ~= nil
end

---connect server
---@param address? string address of neopyter server
function JupyterLab:connect(address)
    self.client:connect(address)
    if self.client:is_connecting() then
        local jupyterlab_version = self:get_jupyterlab_extension_version()
        local nvim_version = self:get_nvim_plugin_version()
        if jupyterlab_version ~= nil and nvim_version ~= jupyterlab_version then
            utils.notify_error(
                string.format("The version of jupyterlab extension(%s) and neovim plugin(%s) do not match", jupyterlab_version, nvim_version)
            )
        end
    end
end

function JupyterLab:disconnect(address)
    self.client:disconnect(address)
end

function JupyterLab:is_connecting()
    return self.client:is_connecting()
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
    local jupyter = require("neopyter.jupyter")
    local file_path = JupyterLab:_get_buf_local_path(buf)
    local notebook = self.notebook_map[file_path]
    if notebook == nil then
        notebook = Notebook:new({
            client = self.client,
            bufnr = buf,
            local_path = file_path,
        })
        self.notebook_map[file_path] = notebook
        jupyter.notebook = notebook
        notebook:attach()
        local config = require("neopyter").config
        if type(config.on_attach) == "function" then
            vim.schedule(function()
                config.on_attach(buf)
            end)
        end
    end

    if self:is_connecting() and notebook:is_exist() then
        if notebook:is_open() then
            notebook:activate()
        else
            notebook:open_or_reveal()
        end
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

---get remote version
---@return string|nil
function JupyterLab:get_jupyterlab_extension_version()
    return self.client:request("getVersion")
end

function JupyterLab:get_nvim_plugin_version()
    local path = Path:new(__filepath__):parent():parent():parent():parent():joinpath("package.json")
    local content = utils.read_file(tostring(path))
    local packageJson = vim.json.decode(content)
    return packageJson["version"]
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

JupyterLab = async_wrap(JupyterLab, {
    "attach",
    "is_attached",
    "is_connecting",
})

return JupyterLab
