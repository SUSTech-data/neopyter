local common = require("lua-tests.neopyter.common")
local query = require("nvim-treesitter.query")

describe("first cell without separator", function()
    before_each(function()
        require("neopyter.treesitter").setup()
        require("neopyter.treesitter").load_query("textobjects")
    end)
    describe("whitespace", function()
        if true then
            --  tree-sitter don't support whitespace module
            return
        end
        it("only one empty line", function()
            local buf = common.load_buffer("")
            -- query.
            local nodes = query.get_capture_matches(buf, "@cell", "textobjects")
            assert.is_equal(1, #nodes)
        end)
        it("only one whitespace line", function()
            local buf = common.load_buffer("")
            -- query.
            local nodes = query.get_capture_matches(buf, "@cell", "textobjects")
            assert.is_equal(1, #nodes)
        end)
        it("multiple whitespace lines", function()
            local buf = common.load_buffer("\n\n")
            -- query.
            local nodes = query.get_capture_matches(buf, "@cell", "textobjects")
            assert.is_equal(1, #nodes)
        end)
    end)

    it("only one line", function()
        local buf = common.load_buffer("foo")
        -- query.
        local nodes = query.get_capture_matches(buf, "@cell", "textobjects")
        assert.is_equal(1, #nodes)
    end)
    it("two line", function()
        local buf = common.load_buffer("foo\nbar")
        -- query.
        local nodes = query.get_capture_matches(buf, "@cell", "textobjects")
        assert.is_equal(1, #nodes)
    end)
    it("two line print", function()
        local buf = common.load_buffer("print('foo')\nprint('bar')")
        -- query.
        local nodes = query.get_capture_matches(buf, "@cell", "textobjects")
        assert.is_equal(1, #nodes)
        print(vim.inspect(nodes))
    end)
end)
