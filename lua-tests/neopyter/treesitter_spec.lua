local ts = require("neopyter.treesitter")
local common = require("lua-tests.neopyter.common")

local function capture_iter_start(query, source, capture, loop)
    local iter = ts.iter_captures(query, source, capture, nil, nil, loop):map(function(node)
        local row = node:start()
        return row
    end)
    if loop then
        return iter
    end
    return iter:totable()
end

describe("iter_captures", function()
    local query = vim.treesitter.query.parse(
        "python",
        [[
            (module
                (comment) @foo
            )
        ]]
    )
    it("empty", function()
        assert.is_same(
            {},
            ts.iter_captures(query, {
                "",
            }, "foo"):totable()
        )
        assert.is_same(
            {},
            ts.iter_captures(query, {
                "a=12",
            }, "foo"):totable()
        )
    end)
    it("multiple line", function()
        assert.is_same(
            { 0, 1 },
            capture_iter_start(query, {
                "# foo",
                "# bar",
            }, "foo")
        )
        assert.is_same(
            { 0, 2 },
            capture_iter_start(query, {
                "# foo",
                "a=1",
                "# bar",
            }, "foo")
        )
    end)
    describe("range", function()
        it("start", function()
            local source = {
                "# foo",
                "# bar",
                "doo",
                "# boo",
            }

            local caps = ts.iter_captures(query, source, "foo", 1)
                :map(function(node)
                    local row = node:start()
                    return row
                end)
                :totable()

            assert.is_same({ 1, 3 }, caps)
        end)
        it("end", function()
            local source = {
                "# foo",
                "# bar",
                "doo",
                "# foo",
                "# boo",
            }

            local caps = ts.iter_captures(query, source, "foo", 1, 4)
                :map(function(node)
                    local row = node:start()
                    return row
                end)
                :totable()

            assert.is_same({ 1, 3 }, caps)
        end)
    end)

    describe("loop", function()
        it("empty", function()
            local iter = capture_iter_start(query, {}, "foo", true)
            assert.is_nil(iter())
            assert.is_nil(iter())
            assert.is_nil(iter())
        end)
        it("single line", function()
            local iter = capture_iter_start(query, {
                "# foo",
            }, "foo", true)
            assert.is_same(0, iter())
            assert.is_same(0, iter())
            assert.is_same(0, iter())
        end)

        it("multiple line", function()
            local iter = capture_iter_start(query, {
                "# foo",
                "a=1",
                "# bar",
            }, "foo", true)
            assert.is_same(0, iter())
            assert.is_same(2, iter())
            assert.is_same(0, iter())
            assert.is_same(2, iter())
            assert.is_same(0, iter())
            assert.is_same(2, iter())
        end)
        it("multiple line", function()
            local iter = capture_iter_start(query, {
                "a=1",
                "# foo",
                "b=1",
                "# bar",
                "#",
            }, "foo", true)
            assert.is_same(1, iter())
            assert.is_same(3, iter())
            assert.is_same(4, iter())
            assert.is_same(1, iter())
            assert.is_same(3, iter())
            assert.is_same(4, iter())
        end)
    end)
end)

describe("doc gen", function()
    local lua_query = vim.treesitter.query.parse(
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
    it("capture", function()
        local code = {
            "---@doc-capture config",
            "---@type Option",
            "local config = {}",

            "---@doc-capture foo",
            "---@see xxx",
            "---@type Option",
            "local default_config = {}",
        }
        local caps = ts.iter_matches(lua_query, code):totable()
        -- print(vim.inspect(caps[1]))
        -- print(vim.inspect(caps[2]))
    end)
end)

describe("string expr", function()
    local query = vim.treesitter.query.parse(
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
    )
    local code = table.concat({
        "# %% [md]",                        -- line 0
        '"""',                              -- line 1
        "this is markdown content",         -- line 2
        "```python",                        -- line 2
        "foo",                              -- line 3
        "```",                              -- line 4
        '"""',                              -- line 5
        "# %% [markdown]",                  -- line 6
        '"""',                              -- line 7
        "this is another markdown content", -- line 8
        "```lua",                           -- line 9
        "bar",                              -- line 10
        "```",                              -- line 11
        '"""',                              -- line 12
    }, "\n")

    local lang_tree = vim.treesitter.get_string_parser(code, "python")
    local root = lang_tree:parse()[1]:root()
    it("start", function()
        local starts = vim.iter(query:iter_captures(root, code, 6))
            :filter(function(id)
                return query.captures[id] == "cellcontent"
            end)
            :map(function(_, node)
                local row = node:start()
                return row
            end)
            :totable()
        assert.is_same({ 8 }, starts)
    end)
    it("end", function()
        local starts = vim.iter(query:iter_captures(root, code, 0, 6))
            :filter(function(id)
                return query.captures[id] == "cellcontent"
            end)
            :map(function(_, node)
                local row = node:start()
                return row
            end)
            :totable()
        ---- FIX: https://github.com/neovim/neovim/issues/31963
        -- assert.is_same({ 1 }, starts)
    end)
end)
