local utils = require("symbols.utils")

local _symbol = require("symbols.symbol")
local Symbol_root = _symbol.Symbol_root

---@alias ProviderAsyncGetSymbols fun(self: Provider, buf: integer, refresh_symbols: fun(root: Symbol), on_fail: fun(), on_timeout: fun()) string?
---@alias ProviderGetSymbols fun(self: Provider, buf: integer): boolean, Symbol?

---@class Provider
---@field new fun(self: Provider, config: table)
---@field supports fun(self: Provider, buf: integer): boolean
---@field async_get_symbols ProviderAsyncGetSymbols | nil
---@field get_symbols ProviderGetSymbols | nil

---@enum LspSymbolKind
local LspSymbolKind = {
	File = 1,
	Module = 2,
	Namespace = 3,
	Package = 4,
	Class = 5,
	Method = 6,
	Property = 7,
	Field = 8,
	Constructor = 9,
	Enum = 10,
	Interface = 11,
	Function = 12,
	Variable = 13,
	Constant = 14,
	String = 15,
	Number = 16,
	Boolean = 17,
	Array = 18,
	Object = 19,
	Key = 20,
	Null = 21,
	EnumMember = 22,
	Struct = 23,
	Event = 24,
	Operator = 25,
	TypeParameter = 26,
}

local LspSymbolKindString = utils.tbl_reverse(LspSymbolKind)

---@param lsp_symbol any
---@param parent Symbol?
---@param level integer
local function rec_tidy_lsp_symbol(lsp_symbol, parent, level)
    ---@param lsp_symbol any
    ---@param parent Symbol?
    ---@param level integer
    local function rec_tidy_document_symbol(lsp_symbol, parent, level)
        if level > 0 then
            lsp_symbol.kind = LspSymbolKindString[lsp_symbol.kind]
            lsp_symbol.detail = lsp_symbol.detail or ""
            lsp_symbol.level = level
            lsp_symbol.parent = parent
            lsp_symbol.children = lsp_symbol.children or {}
            lsp_symbol.tags = nil
            lsp_symbol.deprecated = nil
            lsp_symbol.selectionRange = nil
        end
        for _, child in ipairs(lsp_symbol.children) do
            rec_tidy_document_symbol(child, lsp_symbol, level + 1)
        end
    end

    ---@param lsp_symbol any
    local function tidy_symbol_information(lsp_symbol)
        for _, child in ipairs(lsp_symbol.children) do
            child.kind = LspSymbolKindString[child.kind]
            child.detail = ""
            child.level = 1
            child.parent = lsp_symbol
            child.children = {}
            child.range = vim.deepcopy(child.location.range)
            child.tags = nil
            child.deprecated = nil
            child.location = nil
            child.containerName = nil
        end

        ---@param outer Range
        ---@param inner Range
        ---@return boolean
        local function range_inside(outer, inner)
            return (
                outer.start.line < inner.start.line
                and inner["end"].line < outer["end"].line
            )
        end

        local new_children = {}
        for _, child in ipairs(lsp_symbol.children) do
            if #new_children == 0 then
                table.insert(new_children, child)
                child.level = 1
            else
                local prev = new_children
                local curr = new_children[#new_children]
                if range_inside(curr.range, child.range) then
                    while curr ~= nil and range_inside(curr.range, child.range) do
                        prev = curr
                        curr = curr.children[#curr.children]
                    end
                    table.insert(prev.children, child)
                    child.parent = prev
                    child.level = child.parent.level + 1
                else
                    table.insert(new_children, child)
                end
            end
        end
        lsp_symbol.children = new_children
    end

    lsp_symbol.children = lsp_symbol.children or {}
    if #lsp_symbol.children > 0 then
        if lsp_symbol.children[1].location == nil then
            rec_tidy_document_symbol(lsp_symbol, parent, level)
        else
            tidy_symbol_information(lsp_symbol)
        end
    end
end

---@class LspProvider: Provider
---@field client any
---@field request_timeout integer
local LspProvider = {}
LspProvider.__index = LspProvider

---@param config table
---@return LspProvider
function LspProvider:new(config)
    return setmetatable({
        client = nil,
        request_timeout = config.timeout_ms,
        get_symbols = nil,
    }, self)
end

---@param buf integer
---@return boolean
function LspProvider:supports(buf)
    local clients = vim.lsp.get_clients({ bufnr = buf, method = vim.lsp.protocol.Methods.textDocument_documentSymbol })
    self.client = clients[1]
    return #clients > 0
end

function LspProvider:async_get_symbols(buf, refresh_symbols, on_fail, on_timeout)
    local got_symbols = false

    ---@param sym1 Symbol
    ---@param sym2 Symbol
    ---@return boolean
    local function comp_range(sym1, sym2)
        local s1 = sym1.range.start
        local s2 = sym2.range.start
        return (
            s1.line < s2.line
            or (s1.line == s2.line and s1.character < s2.character)
        )
    end

    ---@param symbol Symbol
    local function sort_symbols(symbol)
        table.sort(symbol.children, comp_range)
        for _, child in ipairs(symbol.children) do
            sort_symbols(child)
        end
    end

    local function handler(err, result, _, _)
        got_symbols = true
        if err ~= nil then
            on_fail()
            return
        end
        local root = Symbol_root()
        root.children = result
        rec_tidy_lsp_symbol(root, nil, 0)
        sort_symbols(root)
        refresh_symbols(root)
    end

    local params = { textDocument = vim.lsp.util.make_text_document_params(buf), }
    local ok, request_id = self.client.request(vim.lsp.protocol.Methods.textDocument_documentSymbol, params, handler)
    if not ok then
        on_fail()
        return
    end

    vim.defer_fn(
        function()
            if got_symbols then return end
            self.client.cancel_request(request_id)
            on_timeout()
        end,
        self.request_timeout
    )
end

---@param ts_node any
---@param buf integer
---@return string
local function get_ts_node_text(ts_node, buf)
    local sline, scol, eline, ecol = ts_node:range()
    return vim.api.nvim_buf_get_text(buf, sline, scol, eline, ecol, {})[1]
end

---@alias TSProviderGetSymbols fun(parser: any, buf: integer): boolean, Symbol

---@type TSProviderGetSymbols
local function vimdoc_get_symbols(parser, buf)
    local rootNode = parser:parse()[1]:root()
    local queryString = [[
        [
            (h1 (heading) @H1)
            (h2 (heading) @H2)
            (h3 (heading) @H3)
            (tag text: (word) @Tag)
        ]
    ]]
    local query = vim.treesitter.query.parse("vimdoc", queryString)
    local kind_to_capture_level = { root = 0, H1 = 1, H2 = 2, H3 = 3, Tag = 4 }
    local root = Symbol_root()
    local current = root
    for id, node, _, _ in query:iter_captures(rootNode, 0) do
        local kind = query.captures[id]
        local row1, col1, row2, col2 = node:range()
        local name = vim.api.nvim_buf_get_text(buf, row1, col1, row2, col2, {})[1]
        local level = kind_to_capture_level[kind]
        local range = {
            ["start"] = { line = row1, character = col1 },
            ["end"] = { line = row2, character = col2 },
        }
        if (
            kind == "Tag" and current.kind == "Tag"
            and range.start.line == current.range.start.line
        ) then
            current.name = current.name .. " " .. name
        else
            while level <= kind_to_capture_level[current.kind] do
                current = current.parent
                assert(current ~= nil)
            end
            ---@type Symbol
            local new = {
                kind = kind,
                name = name,
                detail = "",
                level = level,
                parent = current,
                children = {},
                range = range,
            }
            table.insert(current.children, new)
            current = new
        end
    end

    local function fix_range_ends(node, range_end)
        if node.kind == "Tag" then return end
        node.range["end"].line = range_end
        for i, child in ipairs(node.children) do
            local new_range_end = range_end
            if node.children[i+1] ~= nil then
                new_range_end = node.children[i+1].range["start"].line - 1 or range_end
            end
            fix_range_ends(child, new_range_end)
        end
    end

    local line_count = vim.api.nvim_buf_line_count(buf)
    fix_range_ends(root, line_count)

    return true, root
end

---@type TSProviderGetSymbols
local function markdown_get_symbols(parser, _)
    local rootNode = parser:parse()[1]:root()
    local queryString = [[
        [
            (atx_heading (atx_h1_marker) heading_content: (_) @H1)
            (atx_heading (atx_h2_marker) heading_content: (_) @H2)
            (atx_heading (atx_h3_marker) heading_content: (_) @H3)
            (atx_heading (atx_h4_marker) heading_content: (_) @H4)
            (atx_heading (atx_h5_marker) heading_content: (_) @H5)
            (atx_heading (atx_h6_marker) heading_content: (_) @H6)
        ]
    ]]
    local query = vim.treesitter.query.parse("markdown", queryString)
    local capture_group_to_level = { H1 = 1, H2 = 2, H3 = 3, H4 = 4, H5 = 5, H6 = 6 }
    local root = Symbol_root()
    local current = root
    for id, node, _, _ in query:iter_captures(rootNode, 0) do
        local kind = query.captures[id]
        local row1, col1, row2, col2 = node:range()
        local name = vim.api.nvim_buf_get_text(0, row1, col1, row2, col2, {})[1]
        local level = capture_group_to_level[kind]
        while current.level >= level do
            current = current.parent
            assert(current ~= nil)
        end
        local start_row, start_col, end_row, end_col = node:parent():parent():range()
        local section_range = {
            ["start"] = { line = start_row, character = start_col },
            ["end"] = { line = end_row - 1, character = end_col },
        }
        ---@type Symbol
        local new = {
            kind = kind,
            name = name,
            detail = "",
            level = level,
            parent = current,
            children = {},
            range = section_range,
        }
        table.insert(current.children, new)
        current = new
    end

    return true, root
end

---@type TSProviderGetSymbols
local function json_get_symbols(parser, buf)
    local ts_type_kind = {
        ["object"] = "Object",
        ["array"] = "Array",
        ["true"] = "Boolean",
        ["false"] = "Boolean",
        ["string"] = "String",
        ["number"] = "Number",
        ["null"] = "Null",
    }

    ---@param ts_node any
    ---@return Range
    local function symbol_range_for_ts_node(ts_node)
        local sline, scol, eline, ecol = ts_node:range()
        return {
            start = { line = sline, character = scol },
            ["end"] = { line = eline, character = ecol },
        }
    end

    ---@return string
    local function get_detail(kind, ts_node)
        if kind == "Object" then
            return ""
        elseif kind == "Array" then
            return ""
        elseif kind == "Boolean" then
            return ts_node:type()
        elseif kind == "String" then
            return string.sub(get_ts_node_text(ts_node, buf), 2, -2)
        elseif kind == "Number" then
            return get_ts_node_text(ts_node, buf)
        elseif kind == "Null" then
            return "null"
        end
        assert(false, "unexpected kind: " .. tostring(kind))
        return ""
    end

    local walk_array

    ---@param node Symbol
    ---@param ts_node any
    local function walk_object(node, ts_node)
        for ts_child in ts_node:iter_children() do
            if ts_child:named() then
                local key_node = ts_child:child(0)
                local value_node = ts_child:child(2)
                local kind = ts_type_kind[value_node:type()]
                ---@type Symbol
                local new_symbol = {
                    kind = kind,
                    name = string.sub(get_ts_node_text(key_node, buf), 2, -2),
                    detail = get_detail(kind, value_node),
                    level = node.level + 1,
                    parent = node,
                    children = {},
                    range = symbol_range_for_ts_node(ts_child),
                }
                table.insert(node.children, new_symbol)
                if kind == "Array" then
                    walk_array(new_symbol, value_node)
                elseif kind == "Object" then
                    walk_object(new_symbol, value_node)
                end
            end
        end
    end

    ---@param node Symbol
    ---@param ts_node any
    walk_array = function(node, ts_node)
        local array_index = 0
        for ts_child in ts_node:iter_children() do
            if ts_child:named() then
                local kind = ts_type_kind[ts_child:type()]
                ---@type Symbol
                local new_symbol = {
                    kind = kind,
                    name = tostring(array_index),
                    detail = get_detail(kind, ts_child),
                    level = node.level + 1,
                    parent = node,
                    children = {},
                    range = symbol_range_for_ts_node(ts_child),
                }
                table.insert(node.children, new_symbol)
                if kind == "Array" then
                    walk_array(new_symbol, ts_child)
                elseif kind == "Object" then
                    walk_object(new_symbol, ts_child)
                end
                array_index = array_index + 1
            end
        end
    end

    local root = Symbol_root()
    local ts_root = parser:parse()[1]:root()

    local single_top_level_obj = ts_root:child_count() == 1 and ts_root:named_child_count() > 0
    if single_top_level_obj then root.level = root.level - 1 end

    walk_array(root, ts_root)

    if single_top_level_obj then
        root.level = root.level + 1
        root.children = root.children[1].children
    end

    return true, root
end

---@type TSProviderGetSymbols
local function org_get_symbols(parser, buf)
    local rootNode = parser:parse()[1]:root()
    local query = vim.treesitter.query.parse("org", "(section) @s")
    local root = Symbol_root()
    local current = root
    for _, node, _, _ in query:iter_captures(rootNode, 0) do
        local headline_node = node:child(0)
        local stars_node = headline_node:child(0)
        local stars = get_ts_node_text(stars_node, buf)
        local level = #stars
        local kind = "H" .. tostring(level)
        local item_node = headline_node:child(1)
        local name = get_ts_node_text(item_node, buf)
        while current.level >= level do
            current = current.parent
            assert(current ~= nil)
        end
        local start_row, start_col, end_row, end_col = node:range()
        local section_range = {
            ["start"] = { line = start_row, character = start_col },
            ["end"] = { line = end_row - 1, character = end_col },
        }
        ---@type Symbol
        local new = {
            kind = kind,
            name = name,
            detail = "",
            level = level,
            parent = current,
            children = {},
            range = section_range,
        }
        table.insert(current.children, new)
        current = new
    end

    return true, root
end

---@type TSProviderGetSymbols
local function make_get_symbols(parser, buf)
    local SPECIAL_TARGETS = {
        ".DEFAULT", ".DELETE_ON_ERROR", ".EXPORT_ALL_VARIABLES", ".IGNORE",
        ".INTERMEDIATE", ".LOW_RESOLUTION_TIME", ".NOTINTERMEDIATE", ".NOTPARALLEL",
        ".ONESHELL", ".PHONY", ".POSIX", ".PRECIOUS",
        ".SECONDARY", ".SECONDEXPANSION", ".SILENT", ".SUFFIXES",
    }
    local rootNode = parser:parse()[1]:root()
    local query = vim.treesitter.query.parse("make", "(targets) @t")
    local root = Symbol_root()
    for _, node, _, _ in query:iter_captures(rootNode, 0) do
        local name = get_ts_node_text(node, buf)
        if not vim.tbl_contains(SPECIAL_TARGETS, name) then
            local start_row, start_col, end_row, end_col = node:range()
            local range = {
                ["start"] = { line = start_row, character = start_col },
                ["end"] = { line = end_row - 1, character = end_col },
            }
            ---@type Symbol
            local new = {
                kind = "Target",
                name = name,
                detail = "",
                level = 1,
                parent = root,
                children = {},
                range = range,
            }
            table.insert(root.children, new)
        end
    end
    return true, root
end

---@class TSProvider: Provider
---@field name string
---@field parser (fun(parser: any, buf: integer): boolean, Symbol) | nil
---@field ft string
local TSProvider = {}
TSProvider.__index = TSProvider

---@return TSProvider
function TSProvider:new(_)
    return setmetatable({
        parser = nil,
        ft = "",
        async_get_symbols = nil,
    }, self)
end

---@param buf integer
function TSProvider:supports(buf)
    local ft_to_parser_name = {
        help = "vimdoc",
        markdown = "markdown",
        json = "json",
        jsonl = "json",
        org = "org",
        make = "make",
    }
    local ft = vim.api.nvim_get_option_value("filetype", { buf = buf })
    local parser_name = ft_to_parser_name[ft]
    if parser_name == nil then return false end
    local ok, parser = pcall(vim.treesitter.get_parser, buf, parser_name)
    if not ok then return false end
    self.parser = parser
    self.ft = ft
    return true
end

---@param buf integer
---@return boolean, Symbol?
function TSProvider:get_symbols(buf)
    ---@type table<string, ProviderGetSymbols>
    local get_symbols_funs = {
        help = vimdoc_get_symbols,
        markdown = markdown_get_symbols,
        json = json_get_symbols,
        jsonl = json_get_symbols,
        org = org_get_symbols,
        make = make_get_symbols,
    }
    local get_symbols = get_symbols_funs[self.ft]
    assert(get_symbols ~= nil, "Failed to get `get_symbols` for ft: " .. tostring(self.ft))
    return get_symbols(self.parser, buf)
end

return {
    LspProvider = LspProvider,
    TSProvider = TSProvider,
}
