local common = require("lua-tests.neopyter.common")
local ts = require("neopyter.treesitter")

describe("parse separator", function()
    it("percent format", function()
        assert.is_same(
            { "celltype", "Optional title", 'key="value" key2=1' },
            { ts.parse_separator('# %% Optional title [celltype] key="value" key2=1') }
        )
    end)
end)

describe("register", function()
    before_each(function()
        ts.setup()
        ts.load_query("textobjects")
    end)
    it("predicate", function()
        ts.setup()
        local ret = vim.iter(vim.treesitter.query.list_predicates()):find("match-cellseparator?")
        assert.not_nil(ret)
    end)
    it("directive", function()
        ts.setup()
        local ret = vim.iter(vim.treesitter.query.list_directives()):find("set-cell-metadata!")
        assert.not_nil(ret)
    end)
end)

describe("match-cellseparator", function()
    before_each(function()
        ts.setup()
        ts.load_query("cells")
    end)
    it("vanilla", function()
        local code = "# %%"
        local buf = common.load_buffer(code)
        local captures = ts.iter_capture_matches(buf, "cellseparator", "cells"):totable()
        assert.is_same(1, #captures)
        local _id, _node, metadata, _match = unpack(captures[1])
        assert.is_same({
            ["cell-metadata"] = "",
            ["cell-title"] = "",
            ["cell-type"] = "code",
        }, metadata)
    end)
    it("percent format", function()
        local code = '# %% Optional title [celltype] key="value" key2=1'
        local buf = common.load_buffer(code)
        local captures = ts.iter_capture_matches(buf, "cellseparator", "cells"):totable()
        assert.is_same(1, #captures)
        local _id, _node, metadata, _match = unpack(captures[1])
        assert.is_same({
            ["cell-metadata"] = 'key="value" key2=1',
            ["cell-title"] = "Optional title",
            ["cell-type"] = "celltype",
        }, metadata)
    end)
    it("markdown [md]", function()
        local code = "# %% [md]"
        local buf = common.load_buffer(code)
        local captures = ts.iter_capture_matches(buf, "cellseparator", "cells"):totable()
        assert.is_same(1, #captures)
        local _id, _node, metadata, _match = unpack(captures[1])
        assert.is_same({
            ["cell-metadata"] = "",
            ["cell-title"] = "",
            ["cell-type"] = "markdown",
        }, metadata)
    end)
    it("markdown [markdown]", function()
        local code = "# %% [markdown]"
        local buf = common.load_buffer(code)
        local captures = ts.iter_capture_matches(buf, "cellseparator", "cells"):totable()
        assert.is_same(1, #captures)
        local _id, _node, metadata, _match = unpack(captures[1])
        assert.is_same({
            ["cell-metadata"] = "",
            ["cell-title"] = "",
            ["cell-type"] = "markdown",
        }, metadata)
    end)
end)

describe("match-cellseparator", function()
    before_each(function()
        ts.setup()
        ts.load_query("cells")
    end)

    it("percent format", function()
        local code = {
            "# %%",
            '# %% Optional title [celltype] key="value" key2=1',
        }

        local buf = common.load_buffer(code)
        local captures = ts.iter_capture_matches(buf, "cellseparator", "cells"):totable()
        assert.is_same(2, #captures)
        assert.is_same({
            ["cell-metadata"] = "",
            ["cell-title"] = "",
            ["cell-type"] = "code",
        }, captures[1][3])
        assert.is_same({
            ["cell-metadata"] = 'key="value" key2=1',
            ["cell-title"] = "Optional title",
            ["cell-type"] = "celltype",
        }, captures[2][3])
    end)
end)
