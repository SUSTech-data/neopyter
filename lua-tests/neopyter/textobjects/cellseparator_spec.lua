local common = require("lua-tests.neopyter.common")
local query = require("nvim-treesitter.query")

describe("cellseparator", function()
    before_each(function()
        require("neopyter.treesitter").setup()
        require("neopyter.treesitter").load_query("textobjects")
    end)
    it("vanilla", function()
        local buf = common.load_buffer("# %%")
        local nodes = query.get_capture_matches(buf, "@cellseparator", "textobjects")
        assert.is_equal(1, #nodes)
    end)
    describe("markdown", function()
        it("[markdown]", function()
            local code = "# %% [markdown]"
            local buf = common.load_buffer(code)
            local nodes = query.get_capture_matches(buf, "@cellseparator", "textobjects")
            assert.is_equal(1, #nodes)
        end)
        it("[md]", function()
            local code = "# %% [md]"
            local buf = common.load_buffer(code)
            local nodes = query.get_capture_matches(buf, "@cellseparator", "textobjects")
            assert.is_equal(1, #nodes)
        end)
    end)
    describe("raw", function()
        it("vanilla", function()
            local code = "# %% [md]"
            local buf = common.load_buffer(code)
            local nodes = query.get_capture_matches(buf, "@cellseparator", "textobjects")
            assert.is_equal(1, #nodes)
        end)
    end)
end)
