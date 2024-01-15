local utils = require("neopyter.utils")

describe("relative path", function()
    it("Unik-like format", function()
        assert.are.same("internal/a.txt", utils.relative_to("/tmp/book/internal/a.txt", "/tmp/book/"))
        -- plenary.path don't support, refer to https://github.com/nvim-lua/plenary.nvim/issues/411
        -- assert.are.same("internal/a.txt", utils.relative_to("/tmp/book/internal/a.txt", "/tmp/book/other_internal"))
    end)
end)

describe("absolute path", function()
    it("Unik-like format", function()
        assert.are.same(true, utils.is_absolute("/tmp/book/internal/a.txt"))
        assert.are.same(false, utils.is_absolute("book/internal/a.txt"))
        -- plenary.path don't support, refer to https://github.com/nvim-lua/plenary.nvim/issues/411
        -- assert.are.same("internal/a.txt", utils.relative_to("/tmp/book/internal/a.txt", "/tmp/book/other_internal"))
    end)
end)

describe("parse notebook", function()
    describe("code cell", function()
        it("single cell", function()
            local cells = utils.parse_content({
                "# %%",
                "print('hello')",
            })
            assert.are.same({
                {
                    lines = { "# %%", "print('hello')" },
                    source = "print('hello')",
                    start_line = 1,
                    end_line = 3,
                    cell_type = "code",
                },
            }, cells)
        end)
        it("only mark", function()
            local cells = utils.parse_content({
                "# %%",
            })
            assert.are.same({
                {
                    lines = { "# %%" },
                    source = "",
                    start_line = 1,
                    end_line = 2,
                    cell_type = "code",
                },
            }, cells)
        end)
        it("without any mark", function()
            local cells = utils.parse_content({
                "print('hello')",
            })
            assert.are.same({
                {
                    lines = { "print('hello')" },
                    source = "print('hello')",
                    start_line = 1,
                    end_line = 2,
                    cell_type = "code",
                    no_separator = true,
                },
            }, cells)
        end)
        it("mutiple cells", function()
            local cells = utils.parse_content({
                "# %%",
                "print('hello')",
                "# %% cell's title",
                "print('world')",
            })
            assert.are.same({
                {
                    lines = { "# %%", "print('hello')" },
                    source = "print('hello')",
                    start_line = 1,
                    end_line = 3,
                    cell_type = "code",
                },
                {
                    lines = { "# %% cell's title", "print('world')" },
                    source = "print('world')",
                    start_line = 3,
                    end_line = 5,
                    title = "cell's title",
                    cell_type = "code",
                },
            }, cells)
        end)
    end)
    describe("magic", function()
        it("cell magic", function()
            local cells = utils.parse_content({
                "# %%timeit",
                "print('hello')",
            })
            assert.are.same({
                {
                    lines = { "# %%timeit", "print('hello')" },
                    source = "%%timeit\nprint('hello')",
                    start_line = 1,
                    end_line = 3,
                    cell_magic = "%%timeit",
                    cell_type = "code",
                },
            }, cells)
        end)
        it("cell magic with params", function()
            local cells = utils.parse_content({
                "# %%timeit -arg=12",
                "print('hello')",
            })
            assert.are.same({
                {
                    lines = { "# %%timeit -arg=12", "print('hello')" },
                    source = "%%timeit -arg=12\nprint('hello')",
                    start_line = 1,
                    end_line = 3,
                    cell_magic = "%%timeit -arg=12",
                    cell_type = "code",
                },
            }, cells)
        end)

        it("line magic", function()
            local cells = utils.parse_content({
                "# %%",
                "# %time",
                "print('hello')",
            })
            assert.are.same({
                {
                    lines = { "# %%", "# %time", "print('hello')" },
                    source = "%time\nprint('hello')",
                    start_line = 1,
                    end_line = 4,
                    cell_type = "code",
                },
            }, cells)
        end)
        it("line magic with params", function()
            local cells = utils.parse_content({
                "# %time -arg=12",
                "print('hello')",
            })
            assert.are.same({
                {
                    lines = { "# %time -arg=12", "print('hello')" },
                    source = "%time -arg=12\nprint('hello')",
                    start_line = 1,
                    end_line = 3,
                    no_separator = true,
                    cell_type = "code",
                },
            }, cells)
        end)
    end)
    describe("markdown", function()
        it("[md]", function()
            local cells = utils.parse_content({
                "# %%[md]",
                '"""',
                "this is markdown content",
                '"""',
            })
            assert.are.same({
                {
                    lines = { "# %%[md]", '"""', "this is markdown content", '"""' },
                    source = "this is markdown content",
                    start_line = 1,
                    end_line = 5,
                    cell_type = "markdown",
                },
            }, cells)
        end)
        it("[markdown]", function()
            local cells = utils.parse_content({
                "# %%[markdown]",
                '"""',
                "this is markdown content",
                '"""',
            })
            assert.are.same({
                {
                    lines = { "# %%[markdown]", '"""', "this is markdown content", '"""' },
                    source = "this is markdown content",
                    start_line = 1,
                    end_line = 5,
                    cell_type = "markdown",
                },
            }, cells)
        end)
        it("cell's title [markdown]", function()
            local cells = utils.parse_content({
                "# %% cell's title [markdown]",
                '"""',
                "# this is markdown cell with markdown too",
                '"""',
            })
            assert.are.same({
                {
                    lines = {
                        "# %% cell's title [markdown]",
                        '"""',
                        "# this is markdown cell with markdown too",
                        '"""',
                    },
                    source = "# this is markdown cell with markdown too",
                    start_line = 1,
                    end_line = 5,
                    title= "cell's title",
                    cell_type = "markdown",
                },
            }, cells)
        end)
    end)
end)
