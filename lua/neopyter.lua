local highlight = require("neopyter.highlight")
local treesitter = require("neopyter.treesitter")
local textobject = require("neopyter.textobject")
local injection = require("neopyter.injection")
local jupyter = require("neopyter.jupyter")
local JupyterLab = require("neopyter.jupyter.jupyterlab")
local utils = require("neopyter.utils")

---@class neopyter.Option
---@field remote_address? string
---@field file_pattern? string[]
---@field auto_attach? boolean Automatically attach to the Neopyter server when open file_pattern matched files
---@field auto_connect? boolean Auto connect jupyter lab
---@field mode? "direct"|"proxy" Work mode
---@field filename_mapper? fun(ju_path:string):string
---@field on_attach? fun(bufnr:number)
---@field jupyter? neopyter.JupyterOption
---@field highlight? neopyter.HighlightOption
---@field textobject? neopyter.TextObjectOption
---@field injection? neopyter.InjectionOption
---@field parser? neopyter.ParserOption

-- File system
---@nodoc
---@class neopyter.Neopyter
---@field parser {[string]: neopyter.Parser} Parser of language
local neopyter = {}

---@nodoc
---@doc-capture default-config
---@type neopyter.Option
local default_config = {
    remote_address = "127.0.0.1:9001",
    file_pattern = { "*.ju.*" },
    filename_mapper = function(ju_path)
        local ipynb_path = vim.fn.fnamemodify(ju_path, ":r:r:r") .. ".ipynb"
        return ipynb_path
    end,
    --- auto attach to buffer
    auto_attach = true,
    --- auto connect with remote jupyterlab
    auto_connect = true,
    mode = "direct",
    ---@type neopyter.JupyterOption  # ref `:h neopyter.JupyterOption`
    jupyter = {
        auto_activate_file = true,
        -- Always scroll to the current cell.
        scroll = {
            enable = true,
            align = "center",
        },
    },

    ---@type neopyter.HighlightOption  # ref `:h neopyter.HighlightOption`
    highlight = {
        enable = true,
        mode = "separator",
    },
    ---@type neopyter.TextObjectOption  # ref `:h neopyter.TextObjectOption`
    textobject = {
        enable = true,
        queries = { "cellseparator" },
    },
    ---@type neopyter.InjectionOption  # ref `:h neopyter.InjectionOption`
    injection = {
        enable = true,
    },
    ---@type neopyter.ParserOption  # ref `:h neopyter.ParserOption`
    parser = {
        trim_whitespace = false,
        python = {},
    },
}

---@nodoc
---@param config? neopyter.Option
function neopyter.setup(config)
    neopyter.config = vim.tbl_deep_extend("force", default_config, config or {})

    if pcall(require, "neoconf") then
        require("neopyter.neoconf").setup()
    end

    neopyter.load_parser()

    highlight.setup()
    textobject.setup()

    injection.setup()

    jupyter.jupyterlab = JupyterLab:new({
        address = neopyter.config.remote_address,
    })

    if neopyter.config.auto_attach then
        local augroup = vim.api.nvim_create_augroup("neopyter", { clear = true })
        utils.nvim_create_autocmd({ "BufReadPost" }, {
            group = augroup,
            pattern = neopyter.config.file_pattern,
            callback = function()
                vim.api.nvim_del_augroup_by_id(augroup)
                jupyter.jupyterlab:attach()
                if neopyter.config.auto_connect then
                    jupyter.jupyterlab:connect()
                end
            end,
        })
    end
end

---load parser
---@nodoc
function neopyter.load_parser()
    neopyter.parser = {}
    local option = vim.deepcopy(neopyter.config.parser)
    ---@cast option any
    local PercentParser = require("neopyter.parser.percent")
    local python_spec_option = option.python
    option.python = nil
    local python_option = vim.tbl_deep_extend("force", option, python_spec_option) --[[@as neopyter.PercentParserOption ]]
    neopyter.parser["python"] = PercentParser:new(python_option)
end

---@tag neopyter-api
---@toc_entry API
return neopyter
