#!/usr/bin/env -S nvim -l
local root = vim.fn.fnamemodify(".docs", ":p")

for _, name in ipairs({ "config", "data", "state", "cache" }) do
    vim.env[("XDG_%s_HOME"):format(name:upper())] = root .. "/" .. name
end
vim.opt.packpath:append(vim.fs.joinpath(vim.fn.stdpath("data"), "site"))

local __project_root__ = vim.fs.dirname(vim.fs.dirname(vim.fs.abspath(debug.getinfo(1).source:sub(2))))

vim.pack.add({
    "https://github.com/nvim-lua/plenary.nvim",
    "https://github.com/pysan3/pathlib.nvim",
    "https://github.com/nvim-neotest/nvim-nio",
    "https://github.com/kdheepak/panvimdoc",
    { src = "https://github.com/nvim-treesitter/nvim-treesitter", version = "main" },
})

vim.opt.rtp:append(__project_root__)
vim.opt.rtp:append(vim.fs.joinpath(__project_root__, "after"))

require("nvim-treesitter").setup({})
require 'nvim-treesitter'.install { "lua", "python", "markdown" }:wait(300000)

local ts = require("neopyter.treesitter")

local fmt = string.format

local Path = require("pathlib")

local nvim_gen_files = {
    "gen_vimdoc.lua",
    "util.lua",
    "luacats_grammar.lua",
    "luacats_parser.lua",
}

local config = {
    neopyter = {
        filename = "neopyter.txt",
        section_order = {
            "neopyter.lua",
            "highlight.lua",
            "textobject.lua",
            "injection.lua",
            "completer.lua",
        },
        files = {
            "lua/neopyter.lua",
            "lua/neopyter/highlight.lua",
            "lua/neopyter/textobject.lua",
            "lua/neopyter/injection.lua",
            "lua/neopyter/completer.lua",
        },
        fn_xform = function(fun)
            if fun.classvar then
                return
            end

            fun.name = fmt("%s.%s", fun.module, fun.name)
        end,
        section_fmt = function(name)
            return "Configuration Types"
        end,
        helptag_fmt = function(name)
            return "neopyter-configuration-types"
        end,
        append_only = {
            "highlight.lua",
            "textobject.lua",
            "injection.lua",
            "completer.lua",
        },
    },
    api = {
        filename = "neopyter-api.txt",
        section_order = {
            "jupyterlab.lua",
            "notebook.lua",
            "treesitter.lua",
        },
        files = {
            "lua/neopyter/jupyter/jupyterlab.lua",
            "lua/neopyter/jupyter/notebook.lua",
            "lua/neopyter/treesitter.lua",
        },
        fn_xform = function(fun)
            if fun.module and vim.endswith(fun.module, "treesitter.lua") then
                return
            end
            if vim.startswith(fun.name, "treesitter") then
                fun.name = vim.split(fun.name, "%.")[2]
                fun.module = "lua.neopyter.jupyter.treesitter.lua"
                return
            end
            if fun.classvar then
                return
            end

            fun.name = fmt("%s.%s", fun.module, fun.name)
        end,
        section_fmt = function(name)
            return "Neopyter module: " .. name
        end,
        helptag_fmt = function(name)
            return "neopyter-" .. name:lower() .. "-api"
        end,
        fn_helptag_fmt = function(fun)
            if fun.module and vim.endswith(fun.module, "treesitter.lua") then
                return "neopyter-treesitter-" .. fun.name
            end
            local fn_sfx = fun.table and "" or "()"
            if fun.classvar then
                return fmt("%s:%s%s", fun.classvar, fun.name, fn_sfx)
            end
            if fun.module then
                return fmt("%s.%s%s", fun.module, fun.name, fn_sfx)
            end
            return fun.name .. fn_sfx
        end,
    },
    parser = {
        filename = "neopyter-parser.txt",
        section_order = {
            "parser.lua",
        },
        files = {
            "lua/neopyter/parser/parser.lua",
        },
        fn_xform = function(fun)
            if fun.classvar then
                return
            end

            fun.name = fmt("%s.%s", fun.module, fun.name)
        end,
        section_fmt = function(name)
            return "Neopyter module: " .. name
        end,
        helptag_fmt = function(name)
            return "neopyter-" .. name:lower()
        end,
    },
}

local panvimdoc_path = Path.stdpath("data") / "site/pack/core/opt/panvimdoc/panvimdoc.sh"

local neopyter_entry = Path("lua/neopyter.lua"):absolute()
local readme_entry = Path("README.md"):absolute()

local function download_nvim_gen()
    local cache_path = Path.stdpath("cache", "gen_doc")
    vim.opt.rtp:append(tostring(cache_path))
    local script_path = cache_path / "lua/gen"
    script_path:mkdir(Path.permission("rwxr-xr-x"), true)
    local entry_script = script_path / "gen_vimdoc.lua"

    for i, file in pairs(nvim_gen_files) do
        local cmd =
            string.format("curl -s https://raw.githubusercontent.com/neovim/neovim/refs/heads/master/src/gen/%s -o %s", file, script_path / file)
        vim.fn.system(cmd)
    end
    local entry = entry_script:fs_read()
    ---@cast entry -nil
    local doc_path = Path("."):absolute() / "doc"

    entry = entry:gsub([[local cdoc_parser = require%('gen.cdoc_parser'%)]], "")
    entry = entry:gsub([[c = cdoc_parser.parse,]], "")
    entry = entry:gsub([[h = cdoc_parser.parse,]], "")
    entry = entry:gsub([[local function run%(%)]], [[local function run(config)]])
    entry = entry:gsub([[run%(%)]], [[return run]])
    entry = entry:gsub([[error%(fmt%('not found: %%s in %%s', tokenstr, doc_file%)%)]], "return")
    entry = entry:gsub(
        [[local doc_file = vim.fs.joinpath%(base_dir, 'runtime', 'doc', cfg.filename%)]],
        string.format("local doc_file = vim.fs.joinpath('%s', cfg.filename)", doc_path)
    )
    entry = entry:gsub("sdoc = %S+", "sdoc = (add_header and '\\n\\n' or '')")
    entry_script:fs_write(entry)
end

local function inject_markdown()
    local query = vim.treesitter.query.parse(
        "lua",
        [[
            (chunk
              (comment) @doc-capture
                .
                ((comment)+) @doc-comment
                .
                (variable_declaration) @doc-variable

                (#lua-match? @doc-capture "---@doc%-capture %w+")
                (#gsub! @doc-capture "---@doc%-capture (%w+)" "%1")
              )
        ]]
    )
    local source = neopyter_entry:fs_read()
    ---@cast source -nil
    local inject_map = {}
    for pattern, match, metadata in ts.iter_matches(query, source) do
        local key
        local code = {}
        for id, nodes in pairs(match) do
            local name = query.captures[id]
            if name == "doc-capture" then
                key = metadata[id].text
            else
                for _, node in ipairs(nodes) do
                    table.insert(code, vim.treesitter.get_node_text(node, source))
                end
            end
        end

        inject_map[key] = table.concat(code, "\n")
    end
    local readme = readme_entry:fs_read()
    ---@cast readme -nil
    local start, stop, name = readme:find("doc%-inject:(%S*)")
    while start do
        assert(inject_map[name], string.format("can't find capture [%s] in neopyter.lua", name))
        local _, inject_start = readme:find("```lua", stop)
        local inject_end = readme:find("```", inject_start)
        assert(inject_start and inject_end, "can't find lua code block in README.md")
        print(string.format("Inject %s to README.md", name))
        readme = readme:sub(0, inject_start + 1) .. inject_map[name] .. readme:sub(inject_end - 1)

        start, stop, name = readme:find("doc%-inject:(%S*)", stop)
    end
    readme_entry:fs_write(readme)
    print("Update README.md")
end

local function generate_doc()
    download_nvim_gen()
    inject_markdown()
    local out = vim.system({
        tostring(panvimdoc_path),
        -- "--doc-mapping",
        -- "false",
        "--doc-mapping-project-name",
        "false",
        "--project-name",
        "neopyter",
        "--input-file",
        "README.md",
    }, {
        env = {
            GITHUB_ACTIONS = "false"
        }
    }):wait()

    assert(out.code == 0, vim.inspect(out))

    require("gen/gen_vimdoc")(config)
end

generate_doc()
