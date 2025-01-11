describe("lpeg", function()
    it("number", function()
        local pattern = vim.re.compile(
            [[
                number <- <mpm> <digits> ("." <digits>)? (<exp> <mpm> <digits>)?
                mpm <- ("+"/"-")?
                digits <- %d+
                exp <- "e"/"E"
            ]],
            vim.tbl_deep_extend("keep", {
                tonumber = tonumber,
            }, vim.lpeg.locale())
        )
        assert.is_not_nil(pattern:match("0"))
        assert.is_not_nil(pattern:match("12"))
        assert.is_not_nil(pattern:match("-12"))
        assert.is_not_nil(pattern:match("1.23"))
        assert.is_not_nil(pattern:match("-1.23"))
        assert.is_not_nil(pattern:match("1e1"))
        assert.is_not_nil(pattern:match("1e-10"))
        assert.is_nil(pattern:match(""))
        assert.is_equal(4, pattern:match("1.2.1"))
    end)

end)
