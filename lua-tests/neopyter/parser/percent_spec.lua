local PercentParser = require("neopyter.parser.percent")
local common = require("lua-tests.neopyter.common")

describe("parse percent", function()
    describe("metadata", function()
        it("pair", function()
            local pattern = vim.re.compile(
                [[
                pair <- {| <key> "="  <value> |}
                space <- %s*  
                key <- {%w+}
                value <- number/string
                 
                number <- {<mpm> <digits> ("." <digits>)? (<exp> <mpm> <digits>)?} -> tonumber
                mpm <- ("+"/"-")?
                digits <- %d+
                exp <- "e"/"E"
                
                string <- '"' {%w+} '"'
            ]],
                {
                    tonumber = tonumber,
                }
            )
            assert.is_same({ "d", 12 }, pattern:match([[d=12]]))
            assert.is_same({ "d", "12" }, pattern:match([[d="12"]]))
            assert.is_same({ "foo", "bar" }, pattern:match([[foo="bar"]]))
        end)
        it("pairs", function()
            local pattern = vim.re.compile(
                [[
                pairs <- {| (pair space)* |}
                pair <- {| <key> "="  <value> |}
                space <- %s*  
                key <- {%w+}
                value <- number/string
                 
                number <- {<mpm> <digits> ("." <digits>)? (<exp> <mpm> <digits>)?} -> tonumber
                mpm <- ("+"/"-")?
                digits <- %d+
                exp <- "e"/"E"
                
                string <- '"' {%w+} '"'
            ]],
                {
                    tonumber = tonumber,
                }
            )
            assert.is_same({ { "d", 12 } }, pattern:match([[d=12]]))
            assert.is_same({ { "d", "12" } }, pattern:match([[d="12"]]))
            assert.is_same({ { "foo", "bar" } }, pattern:match([[foo="bar"]]))
        end)
    end)
    it("percent format", function()
        assert.is_same({}, { PercentParser.parse_percent("foo") })
        assert.is_same({}, { PercentParser.parse_percent("# %") })
        assert.is_same({}, { PercentParser.parse_percent("# %%dd") })
        assert.is_same({ "code" }, { PercentParser.parse_percent("# %%") })
        assert.is_same({ "code", "foo" }, { PercentParser.parse_percent("# %% foo") })
        assert.is_same({ "markdown" }, { PercentParser.parse_percent("# %% [md]") })
        assert.is_same({ "markdown" }, { PercentParser.parse_percent("# %% [markdown] ") })
        assert.is_same({ "markdown", nil, "key=12" }, { PercentParser.parse_percent("# %% [markdown] key=12") })
        assert.is_same({ "markdown", nil, "key=12 12" }, { PercentParser.parse_percent("# %% [markdown] key=12 12") })
        --
        assert.is_same(
            { "celltype", "Optional title", 'key="value" key2=1' },
            { PercentParser.parse_percent('# %% Optional title [celltype] key="value" key2=1') }
        )
    end)
end)

describe("cells parse", function()
    ---@type neopyter.PercentParser
    local parser
    before_each(function()
        parser = PercentParser:new({
            trim_whitespace = false,
        })
    end)

    describe("register", function()
        it("predicate", function()
            local ret = vim.iter(vim.treesitter.query.list_predicates()):find("match-percent-separator?")
            assert.not_nil(ret)
        end)
        it("directive", function()
            local ret = vim.iter(vim.treesitter.query.list_directives()):find("set-percent-metadata!")
            assert.not_nil(ret)
        end)
    end)

    it("single empty line", function()
        local code = common.load_buffer("")

        local cells = parser:parse_notebook(code).cells
        assert.are.same({
            {
                start_row = 0,
                end_row = 0,
                no_separator = true,
                type = "code",
            },
        }, cells)
        assert.equal("", parser:parse_source(code, cells[1]))
    end)
    it("two empty lines", function()
        local code = common.load_buffer({
            "",
            "",
        })
        local cells = parser:parse_notebook(code).cells
        assert.are.same({
            {
                start_row = 0,
                end_row = 1,
                no_separator = true,
                type = "code",
            },
        }, cells)
        assert.equal("\n", parser:parse_source(code, cells[1]))
    end)
    it("vanilla script", function()
        local code = common.load_buffer({
            "foo=1",
            "",
            "# normal comment",
            "bar=1",
            "#normal comment",
        })
        local cells = parser:parse_notebook(code).cells
        assert.are.same({
            {
                start_row = 0,
                end_row = 4,
                no_separator = true,
                type = "code",
            },
        }, cells)
        assert.equal(common.get_buf_conent(code), parser:parse_source(code, cells[1]))
    end)

    it("single separator", function()
        local code = common.load_buffer({
            "# %%",
        })
        local cells = parser:parse_notebook(code).cells
        assert.are.same({
            {
                start_row = 0,
                end_row = 0,
                type = "code",
            },
        }, cells)
        assert.equal("", parser:parse_source(code, cells[1]))
    end)
    it("separator + title", function()
        local code = common.load_buffer({
            "# %% foo",
        })
        local cells = parser:parse_notebook(code).cells
        assert.are.same({
            {
                start_row = 0,
                end_row = 0,
                type = "code",
                title = "foo",
            },
        }, cells)
        assert.equal("", parser:parse_source(code, cells[1]))
    end)

    it("two separator", function()
        local code = common.load_buffer({
            "# %%",
            "# %%",
        })
        local cells = parser:parse_notebook(code).cells
        assert.are.same({
            {
                start_row = 0,
                end_row = 0,
                type = "code",
            },
            {
                start_row = 1,
                end_row = 1,
                type = "code",
            },
        }, cells)
        assert.equal("", parser:parse_source(code, cells[1]))
        assert.equal("", parser:parse_source(code, cells[2]))
    end)
    it("empty line + separator", function()
        local code = common.load_buffer({
            "",
            "# %%",
        })
        local cells = parser:parse_notebook(code).cells
        assert.are.same({
            {
                start_row = 0,
                end_row = 0,
                no_separator = true,
                type = "code",
            },
            {
                start_row = 1,
                end_row = 1,
                type = "code",
            },
        }, cells)
        assert.equal("", parser:parse_source(code, cells[1]))
        assert.equal("", parser:parse_source(code, cells[2]))
    end)

    it("three normal cell", function()
        local code = common.load_buffer({
            "import foo",
            "# %%",
            "bar=1",
            "# %%",
            "boo=1",
        })
        local cells = parser:parse_notebook(code).cells
        assert.are.same({
            {
                start_row = 0,
                end_row = 0,
                no_separator = true,
                type = "code",
            },
            {
                start_row = 1,
                end_row = 2,
                type = "code",
            },
            {
                start_row = 3,
                end_row = 4,
                type = "code",
            },
        }, cells)
        assert.equal("import foo", parser:parse_source(code, cells[1]))
        assert.equal("bar=1", parser:parse_source(code, cells[2]))
        assert.equal("boo=1", parser:parse_source(code, cells[3]))
    end)
    describe("cell magic", function()
        it("empty body", function()
            local code = common.load_buffer({
                "# %%",
                "# %%coo",
            })
            local cells = parser:parse_notebook(code).cells
            assert.are.same({
                {
                    start_row = 0,
                    end_row = 1,
                    type = "code",
                },
            }, cells)
            assert.equal("%%coo", parser:parse_source(code, cells[1]))
        end)
        it("single line cell", function()
            local code = common.load_buffer({
                "# %%",
                "# %%coo",
                "# foo",
            })
            local cells = parser:parse_notebook(code).cells
            assert.are.same({
                {
                    start_row = 0,
                    end_row = 2,
                    type = "code",
                },
            }, cells)
            assert.equal("%%coo\nfoo", parser:parse_source(code, cells[1]))
        end)

        it("single empty line cell", function()
            local code = common.load_buffer({
                "# %%",
                "# %%coo",
                "",
            })
            local cells = parser:parse_notebook(code).cells
            assert.are.same({
                {
                    start_row = 0,
                    end_row = 2,
                    type = "code",
                },
            }, cells)
            assert.equal("%%coo\n", parser:parse_source(code, cells[1]))
        end)
        it("single line cell", function()
            local code = common.load_buffer({
                "# %%",
                "# %%coo",
                "import foo",
            })
            local cells = parser:parse_notebook(code).cells
            assert.are.same({
                {
                    start_row = 0,
                    end_row = 2,
                    type = "code",
                },
            }, cells)
            assert.equal("%%coo\nimport foo", parser:parse_source(code, cells[1]))
        end)
it("multiple lines cell", function()
            local code = common.load_buffer({
                "# %%",
                "# %%coo",
                "import foo",
                "",
                "# bar"
            })
            local cells = parser:parse_notebook(code).cells
            assert.are.same({
                {
                    start_row = 0,
                    end_row = 4,
                    type = "code",
                },
            }, cells)
            assert.equal("%%coo\nimport foo\n\n# bar", parser:parse_source(code, cells[1]))
        end)

        it("string expr body", function()
            local code = common.load_buffer({
                "# %%",
                "# %%js",
                '"""',
                "console.log('hello')",
                '"""',
            })
            local cells = parser:parse_notebook(code).cells
            assert.are.same({
                {
                    start_row = 0,
                    end_row = 4,
                    type = "code",
                },
            }, cells)
            assert.equal("%%js\nconsole.log('hello')", parser:parse_source(code, cells[1]))
        end)
        describe("invalid cell magic:", function()
            it("space between separator and magic", function()
                local code = common.load_buffer({
                    "# %%",
                    "",
                    "# %%coo",
                })
                local cells = parser:parse_notebook(code).cells
                assert.are.same({
                    {
                        start_row = 0,
                        end_row = 2,
                        type = "code",
                    },
                }, cells)
                assert.equal("\n# %%coo", parser:parse_source(code, cells[1]))
            end)
            it("first line", function()
                local code = common.load_buffer({
                    "# %%coo",
                })
                local cells = parser:parse_notebook(code).cells
                assert.are.same({
                    {
                        start_row = 0,
                        end_row = 0,
                        no_separator = true,
                        type = "code",
                    },
                }, cells)
                assert.equal("# %%coo", parser:parse_source(code, cells[1]))
            end)
        end)
    end)

    describe("line magic", function()
        it("any position in code cell", function()
            local code = common.load_buffer({
                "# %foo",
                "import foo",
                "# %boo",
                "",
                "# %%",
                "# %coo",
                "",
                "# %%",
                "",
                "boo=1",
                "# %moo",
            })
            local cells = parser:parse_notebook(code).cells
            assert.are.same({
                {
                    start_row = 0,
                    end_row = 3,
                    no_separator = true,
                    type = "code",
                },
                {
                    start_row = 4,
                    end_row = 6,
                    type = "code",
                },
                {
                    start_row = 7,
                    end_row = 10,
                    type = "code",
                },
            }, cells)
            assert.equal("%foo\nimport foo\n%boo\n", parser:parse_source(code, cells[1]))
            assert.equal("%coo\n", parser:parse_source(code, cells[2]))
            assert.equal("\nboo=1\n%moo", parser:parse_source(code, cells[3]))
        end)
        it("invalid ling magic", function()
            local code = common.load_buffer({
                "# %-foo",
                "# %% [md]",
                "# %coo",
                "# %% [markdown]",
                '"""',
                "# %coo",
                '"""',
            })
            local cells = parser:parse_notebook(code).cells
            assert.are.same({
                {
                    start_row = 0,
                    end_row = 0,
                    no_separator = true,
                    type = "code",
                },
                {
                    start_row = 1,
                    end_row = 2,
                    type = "markdown",
                },
                {
                    start_row = 3,
                    end_row = 6,
                    type = "markdown",
                },
            }, cells)
            assert.equal("# %-foo", parser:parse_source(code, cells[1]))
            assert.equal("%coo", parser:parse_source(code, cells[2]))
            assert.equal("# %coo", parser:parse_source(code, cells[3]))
        end)
    end)

    describe("markdown", function()
        it("[md]", function()
            local code = common.load_buffer({
                "# %% [md]",
                '"""',
                "this is markdown content",
                '"""',
            })
            local cells = parser:parse_notebook(code).cells
            assert.are.same({
                {
                    start_row = 0,
                    end_row = 3,
                    type = "markdown",
                },
            }, cells)
            assert.equal("this is markdown content", parser:parse_source(code, cells[1]))
        end)
        it("[markdown]", function()
            local code = common.load_buffer({
                "# %% [markdown]",
                '"""',
                "this is markdown content",
                '"""',
            })
            local cells = parser:parse_notebook(code).cells
            assert.are.same({
                {
                    start_row = 0,
                    end_row = 3,
                    type = "markdown",
                },
            }, cells)
            assert.equal("this is markdown content", parser:parse_source(code, cells[1]))
        end)
        it("begin with #", function()
            local code = common.load_buffer({
                "# %% [md]",
                "# this is markdown content",
            })
            local cells = parser:parse_notebook(code).cells
            assert.are.same({
                {
                    start_row = 0,
                    end_row = 1,
                    type = "markdown",
                },
            }, cells)
            assert.equal("this is markdown content", parser:parse_source(code, cells[1]))
        end)
        it("begin with # and inlcude empty line", function()
            local code = common.load_buffer({
                "# %% [md]",
                "",
                "# this is markdown content",
                "",
            })
            local cells = parser:parse_notebook(code).cells
            assert.are.same({
                {
                    start_row = 0,
                    end_row = 3,
                    type = "markdown",
                },
            }, cells)
            assert.equal("\nthis is markdown content\n", parser:parse_source(code, cells[1]))
        end)
        it("inline code block", function()
            local code = common.load_buffer({
                "# %% [md]",
                '"""',
                "this is markdown content",
                "```python",
                "foo",
                "```",
                '"""',
                "# %% [markdown]",
                '"""',
                "this is another markdown content",
                "```lua",
                "bar",
                "```",
                '"""',
            })
            local cells = parser:parse_notebook(code).cells
            assert.are.same({
                {
                    start_row = 0,
                    end_row = 6,
                    type = "markdown",
                },
                {
                    start_row = 7,
                    end_row = 13,
                    type = "markdown",
                },
            }, cells)
            assert.equal("this is markdown content\n```python\nfoo\n```", parser:parse_source(code, cells[1]))
            assert.equal("this is another markdown content\n```lua\nbar\n```", parser:parse_source(code, cells[2]))
        end)

        it("can't parse string expr", function()
            local code = common.load_buffer({
                "# %% [md]",
                '""',
                "this is markdown content",
                '"""',
            })
            local cells = parser:parse_notebook(code).cells
            assert.are.same({
                {
                    start_row = 0,
                    end_row = 3,
                    type = "markdown",
                },
            }, cells)
            assert.equal('""\nthis is markdown content\n"""', parser:parse_source(code, cells[1]))
        end)
    end)

    describe("raw", function()
        it("[raw]", function()
            local code = common.load_buffer({
                "# %% [raw]",
                '"""',
                "this is raw content",
                '"""',
            })
            local cells = parser:parse_notebook(code).cells
            assert.are.same({
                {
                    start_row = 0,
                    end_row = 3,
                    type = "raw",
                },
            }, cells)
            assert.equal("this is raw content", parser:parse_source(code, cells[1]))
        end)
        it("can't parse string expr", function()
            local code = common.load_buffer({
                "# %% [raw]",
                "foo",
            })
            local cells = parser:parse_notebook(code).cells
            assert.are.same({
                {
                    start_row = 0,
                    end_row = 1,
                    type = "raw",
                },
            }, cells)
            assert.equal("foo", parser:parse_source(code, cells[1]))
        end)
    end)
    describe("vanilla", function()
        it("multiple cells", function()
            local code = common.load_buffer({
                "import foo",
                "# %% draw",
                "foo.draw()",
                "# %% show figure",
                "foo.show()",
            })
            local cells = parser:parse_notebook(code).cells
            assert.are.same({
                {
                    start_row = 0,
                    end_row = 0,
                    no_separator = true,
                    type = "code",
                },
                {
                    start_row = 1,
                    end_row = 2,
                    type = "code",
                    title = "draw",
                },
                {
                    start_row = 3,
                    end_row = 4,
                    type = "code",
                    title = "show figure",
                },
            }, cells)
            assert.equal("import foo", parser:parse_source(code, cells[1]))
            assert.equal("foo.draw()", parser:parse_source(code, cells[2]))
            assert.equal("foo.show()", parser:parse_source(code, cells[3]))
        end)
    end)
end)
describe("parse option", function()
    ---@type neopyter.PercentParser
    local parser
    before_each(function()
        parser = PercentParser:new({
            trim_whitespace = true,
        })
    end)
    describe("trim_whitespace", function()
        describe("code", function()
            it("empty lines", function()
                local code = common.load_buffer({
                    "",
                    "\t",
                })
                local cells = parser:parse_notebook(code).cells
                assert.are.same({
                    {
                        start_row = 0,
                        end_row = 1,
                        no_separator = true,
                        type = "code",
                    },
                }, cells)
                assert.equal("", parser:parse_source(code, cells[1]))
            end)
            it("normal cells", function()
                local code = common.load_buffer({
                    "",
                    "foo",
                    "# %%",
                    "",
                    "bar",
                    "",
                })
                local cells = parser:parse_notebook(code).cells
                assert.are.same({
                    {
                        start_row = 0,
                        end_row = 1,
                        no_separator = true,
                        type = "code",
                    },
                    {
                        start_row = 2,
                        end_row = 5,
                        type = "code",
                    },
                }, cells)
                assert.equal("foo", parser:parse_source(code, cells[1]))
                assert.equal("bar", parser:parse_source(code, cells[2]))
            end)
        end)
        describe("markdown", function()
            it("string expr", function()
                local code = common.load_buffer({
                    "# %% [markdown]",
                    '"""  \t',
                    "\t",
                    "this is markdown content",
                    "",
                    '"""',
                })
                local cells = parser:parse_notebook(code).cells
                assert.are.same({
                    {
                        start_row = 0,
                        end_row = 5,
                        type = "markdown",
                    },
                }, cells)
                assert.equal("this is markdown content", parser:parse_source(code, cells[1]))
            end)
        end)
    end)
end)
