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

