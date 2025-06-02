local H = dofile("tests/utils.lua")

local child = MiniTest.new_child_neovim()
local T = H.new_set(child)

---@param path string
---@param delay integer?
local function test_file(path, delay)
    H.open_file(child, path)
    child.type_keys(":Symbols<cr>")
    if delay ~= nil then vim.loop.sleep(delay) end
    child.type_keys("zR")
    MiniTest.expect.reference_screenshot(child.get_screenshot())
end

T["markdown"] = function() test_file("tests/examples/headings.md") end
T["vimdoc"] = function() test_file("tests/examples/mini-test.txt") end
-- org seems to be no longer supported by nvim-treesitter
-- T["org"] = function() test_file("tests/examples/example.org") end
T["json"] = function() test_file("tests/examples/morty.json") end
T["json-lines"] = function() test_file("tests/examples/example.jsonl") end
T["makefile"] = function() test_file("tests/examples/Makefile") end

-- This test fails in CI for unknown reason.
-- T["lua"] = function() test_file("tests/examples/nvim_lsp_client.lua", 5000) end

-- I don't know why this doesn't work :/ testing manually seems to work
-- T["ruby"] = function() test_file("tests/examples/rails.rb", 3000) end

return T
