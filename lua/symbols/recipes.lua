local M = {}

---@param symbol Symbol
---@return boolean
local function lua_filter(symbol)
    local kind = symbol.kind
    local pkind = symbol.parent.kind
    if kind == "Constant" or kind == "Package" then
        return false
    end
    if (pkind == "Function" or pkind == "Method") then return false end
    return true
end

---@param symbol Symbol
---@return boolean
local function python_filter(symbol)
    local kind = symbol.kind
    local pkind = symbol.parent.kind
    if (pkind == "Function" or pkind == "Method") and kind ~= "Function" then
        return false
    end
    return true
end

---@param symbol Symbol
---@return boolean
local function javascript_filter(symbol)
    local pkind = symbol.parent.kind
    if (pkind == "Function" or pkind == "Method" or pkind == "Constructor") then return false end
    return true
end

M.DefaultFilters = {
    sidebar = {
        symbol_filter = function(ft, symbol)
            if ft == "lua" then return lua_filter(symbol) end
            if ft == "python" then return python_filter(symbol) end
            if ft == "javascript" then return javascript_filter(symbol) end
            if ft == "typescript" then return javascript_filter(symbol) end
            return true
        end,
    },
}

M.AsciiSymbols = {
    providers = {
        lsp = {
            details = {
                lua = function(symbol, ctx)
                    local state = ctx.symbol_states[symbol]
                    local kind = symbol.kind
                    local detail = symbol.detail
                    if (kind == "Function" or kind == "Method") and vim.startswith(detail, "function") then
                        return vim.split(detail, "function ")[2]
                    end
                    if kind == "Number" or kind == "String" or kind == "Boolean" then
                        return "= " .. detail
                    end
                    if kind == "Object" or kind == "Array" then
                        return (state.folded and detail) or ""
                    end
                    if kind == "Package" then
                        if vim.startswith(detail, "if") then return string.sub(detail, 4, -6) end
                        if vim.startswith(detail, "elseif") then return string.sub(detail, 8, -6) end
                        if vim.startswith(detail, "else") then return "" end
                        if vim.startswith(detail, " for") then return string.sub(detail, 6, -1) end
                        if vim.startswith(detail, "while") then return string.sub(detail, 7, -1) end
                        return detail
                    end
                    return detail
                end,
                go = function(symbol, _)
                    local kind = symbol.kind
                    local detail = symbol.detail
                    if kind == "Struct" or kind == "Interface" then return "" end
                    if kind == "Function" or kind == "Method" then
                        if vim.startswith(detail, "func") then
                            return string.sub(detail, 5, -1)
                        end
                        return detail
                    end
                    return detail
                end,
                rust = function(symbol, _)
                    local kind = symbol.kind
                    local detail = symbol.detail
                    if kind == "Function" or kind == "Method" then
                        if vim.startswith(detail, "fn") then
                            return string.sub(detail, 3, -1)
                        end
                        return detail
                    end
                    return detail
                end,
            },
            kinds = {
                json = {
                    Module = "{}",
                    Array = "[]",
                    Boolean = " b",
                    String = " \"",
                    Number = " #",
                    Variable = " ?",
                },
                yaml = {
                    Module = "{}",
                    Array = "[]",
                    Boolean = "b",
                    String = "\"",
                    Number = "#",
                    Variable = "?",
                },
                lua = function(symbol)
                    local level = symbol.level
                    local kind = symbol.kind
                    local pkind = symbol.parent.kind
                    if kind == "Function" then
                        return ((level == 1) and "fun") or "fn"
                    end
                    if (
                        (pkind == "Array" or pkind == "Object")
                        and (kind ~= "Array" and kind ~= "Object")
                    ) then
                        local obj_map = {
                            Boolean = " b",
                            Function = "fn",
                            Number = " #",
                            String = "\"\"",
                            Variable = " ?",
                        }
                        return obj_map[kind] or "  "
                    end
                    if level == 1 and kind == "Object" then return " {}" end
                    if level == 1 and kind == "Array" then return " []" end
                    local map = {
                        Array = "[]",
                        Boolean = "var",
                        Constant = "param",
                        Method = "fun",
                        Number = "var",
                        Object = "{}",
                        Package = "",
                        String = "var",
                        Variable = "var",
                    }
                    return map[symbol.kind]
                end,
                go = {
                    Class = "type",
                    Constant = "const",
                    Field = "",
                    Function = "func",
                    Interface = "interface",
                    Method = "func",
                    Struct = "struct",
                    Variable = "var",
                },
                rust = {
                    Enum = "enum",
                    EnumMember = "",
                    Field = "",
                    Function = "fn",
                    Interface = "trait",
                    Method = "fn",
                    Module = "mod",
                    Object = "",
                    Struct = "struct",
                    TypeParameter = "type",
                },
                python = {
                    Class = "class",
                    Variable = "",
                    Constant = "",
                    Function = "def",
                    Method = "def",
                },
                ruby = {
                    Class = "class",
                    Module = "module",
                    Property = "attr",
                    Constant = "const",
                    Function = "def",
                    Method = "def",
                },
                sh = {
                    Variable = "$",
                    Function = "fun",
                },
                css = {
                    Class = "",
                    Module = "",
                },
                javascript = {
                    Class = "class",
                    Constant = "const",
                    Constructor = "fun",
                    Function = "fun",
                    Method = "fun",
                    Property = "",
                    Variable = "let",
                },
                typescript = {
                    Class = "class",
                    Constant = "const",
                    Constructor = "fun",
                    Function = "fun",
                    Method = "fun",
                    Property = "",
                    Variable = "let",
                },
                default = {
                    File = "file",
                    Module = "module",
                    Namespace = "namespace",
                    Package = "pkg",
                    Class = "class",
                    Method = "fun",
                    Property = "property",
                    Field = "field",
                    Constructor = "constructor",
                    Enum = "enum",
                    Interface = "interface",
                    Function = "fun",
                    Variable = "var",
                    Constant = "const",
                    String = "str",
                    Number = "num",
                    Boolean = "bool",
                    Array = "array",
                    Object = "object",
                    Key = "key",
                    Null = "null",
                    EnumMember = "enum member",
                    Struct = "struct",
                    Event = "event",
                    Operator = "operator",
                    TypeParameter = "type param",
                    Component = "component",
                    Fragment = "fragment",
                }
            }
        },
        treesitter = {
            kinds = {
                help = {
                    H1 = "",
                    H2 = "",
                    H3 = "",
                    Tag = "",
                },
                markdown = {
                    H1 = "",
                    H2 = "",
                    H3 = "",
                    H4 = "",
                    H5 = "",
                    H6 = "",
                },
                json = {
                    Object = "{}",
                    Array = "[]",
                    String = " \"",
                    Number = " #",
                    Boolean = " b",
                    Null = " ?",
                },
                jsonl = {
                    Object = "{}",
                    Array = "[]",
                    String = " \"",
                    Number = " #",
                    Boolean = " b",
                    Null = " ?",
                },
                org = {
                    H1 = "",
                    H2 = "",
                    H3 = "",
                    H4 = "",
                    H5 = "",
                    H6 = "",
                    H7 = "",
                    H8 = "",
                    H9 = "",
                    H10 = "",
                },
                make = {
                    Target = "",
                },
            }
        }
    }
}

M.FancySymbols = {
    providers = {
        lsp = {
            kinds = {
                default = {
                    File = "󰈔",
                    Module = "󰆧",
                    Namespace = "󰅪",
                    Package = "󰏗",
                    Class = "𝓒",
                    Method = "ƒ",
                    Property = "",
                    Field = "󰆨",
                    Constructor = "",
                    Enum = "ℰ",
                    Interface = "󰜰",
                    Function = "ƒ",
                    Variable = "",
                    Constant = "",
                    String = "𝓐",
                    Number = "#",
                    Boolean = "⊨",
                    Array = "󰅪",
                    Object = "⦿",
                    Key = "󰌋",
                    Null = "NULL",
                    EnumMember = "",
                    Struct = "𝓢",
                    Event = "",
                    Operator = "+",
                    TypeParameter = "𝙏",
                    Component = "󰅴",
                    Fragment = "󰅴",
                }
            }
        },
        treesitter = {
            kinds = {
                help = {
                    H1 = "",
                    H2 = "",
                    H3 = "",
                    Tag = "",
                },
                markdown = {
                    H1 = "",
                    H2 = "",
                    H3 = "",
                    H4 = "",
                    H5 = "",
                    H6 = "",
                },
                json = {
                    Object = "󰆧",
                    Array = "󰅪",
                    String = "𝓐",
                    Number = "#",
                    Boolean = "⊨",
                    Null = "?",
                },
                jsonl = {
                    Object = "󰆧",
                    Array = "󰅪",
                    String = "𝓐",
                    Number = "#",
                    Boolean = "⊨",
                    Null = "?",
                },
                org = {
                    H1 = "",
                    H2 = "",
                    H3 = "",
                    H4 = "",
                    H5 = "",
                    H6 = "",
                    H7 = "",
                    H8 = "",
                    H9 = "",
                    H10 = "",
                },
                make = {
                    Target = "",
                }
            }
        },
    }
}

return M
