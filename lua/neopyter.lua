local highlight = require("neopyter.highlight")
local textobject = require("neopyter.textobject")
local injection = require("neopyter.injection")
local jupyter = require("neopyter.jupyter")
local JupyterLab = require("neopyter.jupyter.jupyterlab")
local PercentParser = require("neopyter.parser.percent")
local a = require("neopyter.async")
local api = a.api

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

local is_windows = vim.loop.os_uname().version:match("Windows")

---@nodoc
---@doc-capture default-config
---@type neopyter.Option
local default_config = {
    remote_address = "127.0.0.1:9001",
    file_pattern = { "*.ju.*" },
    filename_mapper = function(ju_path)
        local ipynb_path = vim.fn.fnamemodify(ju_path, ":r:r:r") .. ".ipynb"
        if is_windows then
            ipynb_path = ipynb_path:gsub("\\", "/")
        end
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
        partial_sync = false,
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
        -- more capture, poorer performance
        queries = { "cellseparator", "cellcontent", "cell" },
    },
    ---@type neopyter.InjectionOption  # ref `:h neopyter.InjectionOption`
    injection = {
        enable = true,
    },
    ---@type neopyter.ParserOption  # ref `:h neopyter.ParserOption`
    parser = {
        trim_whitespace = false,
        python = {},
        r = {},
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
        api.nvim_create_autocmd({ "BufReadPost" }, {
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

    local python_spec_option = option.python
    local r_spec_option = option.r
    option.python = nil
    option.r = nil

    if vim.treesitter.language.add("python") then
        python_spec_option = vim.tbl_deep_extend("force", option, python_spec_option)
        neopyter.setup_python_parser(python_spec_option)
    end
    if vim.treesitter.language.add("r") then
        r_spec_option = vim.tbl_deep_extend("force", option, r_spec_option)
        neopyter.setup_r_parser(r_spec_option)
    end
end

function neopyter.setup_python_parser(spec_option)
    local python_option = vim.tbl_deep_extend("force", {
        separator_query = vim.treesitter.query.parse(
            "python",
            [[
            (module
              (comment) @cellseparator
              (#match-percent-separator? @cellseparator)
              (#set-percent-metadata! @cellseparator)
            )
        ]]
        ),
        extract_string_capture = "cellcontent",
        extract_string_query = vim.treesitter.query.parse(
            "python",
            [[
            (module
                (expression_statement
                    (string
                        (string_start)
                        (string_content) @cellcontent
                        (string_end)
                    )
                )
            )
        ]]
        ),
    }, spec_option) --[[@as neopyter.PercentParserOption ]]
    neopyter.parser["python"] = PercentParser:new(python_option)
end

function neopyter.setup_r_parser(spec_option)
    local r_option = vim.tbl_deep_extend("force", {
        separator_query = vim.treesitter.query.parse(
            "r",
            [[
            (program
              (comment) @cellseparator
              (#match-percent-separator? @cellseparator)
              (#set-percent-metadata! @cellseparator)
            )
        ]]
        ),
        extract_string_capture = "cellcontent",
        extract_string_query = vim.treesitter.query.parse(
            "r",
            [[
            (program
                (string
                    content: (string_content) @cellcontent
                )
            )
        ]]
        ),
    }, spec_option) --[[@as neopyter.PercentParserOption ]]
    neopyter.parser["r"] = PercentParser:new(r_option)
end

---@tag neopyter-api
---@toc_entry API
return neopyter
