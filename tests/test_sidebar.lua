local H = dofile("tests/utils.lua")

local child = MiniTest.new_child_neovim()
local T = H.new_set(child)

local symbols = require("symbols")
local internal = symbols._internal

-- params for symbol_at_pos tests
do
    ---@alias Param [Symbols, Pos, Symbol]
    ---@type Param[]
    local params = {}
    local function add_param(param) table.insert(params, param) end

    ---@param line integer zero-indexed
    ---@param character integer zero-indexed
    ---@return Pos
    local function Pos(line, character) return {line = line, character = character} end

    local function build_symbols(symbol_prototypes)
        local function rec(prototype, level, parent)
            prototype.kind = ""
            prototype.detail = ""
            prototype.level = level
            prototype.parent = parent
            local r = prototype.range
            prototype.range = {
                start = { line = r[1], character = r[2] },
                ["end"] = { line = r[3], character = r[4] }
            }
            prototype.range[0] = nil
            prototype.range[1] = nil

            for _, child in ipairs(prototype.children) do
                rec(child, level+1, prototype)
            end
        end

        rec(symbol_prototypes, 0, nil)
        local symbols = internal.Symbols_new()
        symbols.root = symbol_prototypes
        symbols.states = internal.SymbolStates_build(symbol_prototypes)
        return symbols
    end

    ---@param root Symbol
    ---@param name string
    ---@return Symbol
    local function get_symbol(root, name)
        local function rec(symbol)
            if symbol.name == name then return symbol end
            for _, child in ipairs(symbol.children) do
                local res = rec(child)
                if res ~= nil then return res end
            end
            return nil
        end

        local res = rec(root)
        assert(res ~= nil, "Symbol with name: '" .. name .. "' not found.")
        return res
    end

    local symbol_prototypes = {
        name="<root>",
        range = { 0, 0, -1, -1 },
        children = {
            { name = "a", range = { 10, 0, 10, 22}, children = {} },
            {
                -- nested symbol, every child on a separate line
                name = "b",
                range = { 11, 0, 15, 1},
                children = {
                    { name = "b1", range = { 12, 4, 12, 12}, children = {} },
                    { name = "b2", range = { 13, 4, 13, 7 }, children = {} },
                    { name = "b3", range = { 14, 4, 14, 32}, children = {} },
                }
            },
            -- indented symbol
            { name = "c", range = { 16, 8, 16, 20 }, children = {} },
            {
                -- one character overlap
                name = "d",
                range = { 17, 0, 17, 20 },
                children = {
                    { name = "d1", range = { 17, 0,  17, 10 }, children = {} },
                    { name = "d2", range = { 17, 10, 17, 20 }, children = {} },
                }
            },
            {
                -- inline elements
                name = "e",
                range = { 18, 0, 18, 120 },
                children = {
                    { name = "e1", range = { 18, 4,  18, 10 }, children = {} },
                    { name = "e2", range = { 18, 12,  18, 18 }, children = {} },
                    {
                        name = "e3",
                        range = { 18, 20,  18, 40 },
                        children = {
                            { name = "ea1", range = { 18, 23,  18, 33 }, children = {} },
                            { name = "ea2", range = { 18, 35,  18, 38 }, children = {} },
                        }
                    },
                }
            },
        }
    }
    local symbols = build_symbols(symbol_prototypes)

     -- only root
    do
        local symbols = internal.Symbols_new()
        add_param({symbols, Pos(0, 0), symbols.root})
    end

    -- cursor before any symbols
    add_param { symbols, Pos(0, 0), get_symbol(symbols.root, "a") }

    -- cursor inside symbol
    add_param { symbols, Pos(10, 5), get_symbol(symbols.root, "a") }

    -- cursor inside nested symbol
    add_param { symbols, Pos(13, 6), get_symbol(symbols.root, "b2") }

    -- cursor in the same line as a symbol but not inside it
    add_param { symbols, Pos(16, 0), get_symbol(symbols.root, "c") }

    -- one char overlap, take latter
    add_param { symbols, Pos(17, 10), get_symbol(symbols.root, "d2") }

    add_param { symbols, Pos(18, 11), get_symbol(symbols.root, "e1") }
    add_param { symbols, Pos(18, 39), get_symbol(symbols.root, "ea2") }
    -- next line after inline object gives last element of that object
    add_param { symbols, Pos(19, 0), get_symbol(symbols.root, "ea2") }

    T["symbol_at_pos"] = MiniTest.new_set { parametrize = params }
end

local expect_symbol = MiniTest.new_expectation(
    "symbol equality",
    function(left, right) return left.name == right.name end,
    function(left, right) return "left: '" .. left.name .. ", right: '" .. right.name .. "'." end
)

T["symbol_at_pos"][""] = function(symbols, pos, expected_symbol)
    local result = internal.symbol_at_pos(symbols, pos)
    expect_symbol(result, expected_symbol)
end

return T
