local cfg = require("symbols.config")
local utils = require("symbols.utils")
local log = require("symbols.log")

local nvim = require("symbols.nvim")

local _symbol = require("symbols.symbol")
local Symbol_root = _symbol.Symbol_root
local Symbol_path = _symbol.Symbol_path
local Pos_from_point = _symbol.Pos_from_point

local providers = require("symbols.providers")

local M = {}

M.FILE_TYPE_MAIN = "SymbolsSidebar"
M.FILE_TYPE_SEARCH = "SymbolsSearch"
M.FILE_TYPE_HELP = "SymbolsHelp"

---@return number
local function relative_time_ms()
    return vim.uv.hrtime() / 1e6
end

---@type table<string, boolean>
local cmds = {}

---@param name string
---@param cmd fun(t: table)
---@param opts table
local function create_user_command(name, cmd, opts)
    cmds[name] = true
    vim.api.nvim_create_user_command(name, cmd, opts)
end

local function remove_user_commands()
    local keys = vim.tbl_keys(cmds)
    for _, cmd in ipairs(keys) do
        vim.api.nvim_del_user_command(cmd)
        cmds[cmd] = nil
    end
end

local global_autocmd_group = vim.api.nvim_create_augroup("Symbols", { clear = true })

---@type table<integer, integer>
local _prev_flash_highlight_ns = {}

local function _clear_flash_highlights(buf, ns)
    if _prev_flash_highlight_ns[buf] == ns then
        pcall(vim.api.nvim_buf_clear_namespace, buf, ns, 0, -1)
        _prev_flash_highlight_ns[buf] = nil
    end
end

---@param win integer
---@param duration_ms integer
local function flash_highlight_under_cursor(win, duration_ms, lines)
    local buf = vim.api.nvim_win_get_buf(win)

    local prev_ns = _prev_flash_highlight_ns[buf]
    if prev_ns ~= nil then _clear_flash_highlights(buf, prev_ns) end

    local ns = vim.api.nvim_create_namespace("")
    _prev_flash_highlight_ns[buf] = ns
    local line = vim.api.nvim_win_get_cursor(win)[1]
    for i = 1, lines do
        vim.api.nvim_buf_add_highlight(
            buf, ns, "Visual", line - 1 + i - 1, 0, -1
        )
    end
    vim.defer_fn(
        function() _clear_flash_highlights(buf, ns) end,
        duration_ms
    )
end

local SIDEBAR_EXT_NS = vim.api.nvim_create_namespace("SymbolsSidebarExt")

---@param buf integer
---@param highlights Highlight[]
local function buf_add_highlights(buf, highlights)
    for _, hl in ipairs(highlights) do
        hl:apply(buf)
    end
end

--- Get the ancestor of the symbol with level = 1.
---@param symbol Symbol
---@return Symbol
local function get_top_level_ancestor(symbol)
    assert(symbol.level > 0)
    while symbol.level > 1 do
        symbol = symbol.parent
        assert(symbol ~= nil)
    end
    return symbol
end

---@alias RefreshSymbolsFun fun(symbols: Symbol, provider_name: string, provider_config: table)
---@alias KindToHlGroupFun fun(kind: string): string
---@alias KindToDisplayFun fun(kind: string): string

---@class Preview
---@field sidebar Sidebar
---@field win integer
---@field locked boolean
---@field auto_show boolean
---@field keymaps_to_remove string[]
local Preview = {}
Preview.__index = Preview

---@return Preview
function Preview:new()
    return setmetatable({
        sidebar = nil,
        win = -1,
        locked = false,
        auto_show = cfg.default.sidebar.preview.show_always,
        keymaps_to_remove = {},
    }, self)
end

function Preview:close()
    if vim.api.nvim_win_is_valid(self.win) then
        vim.api.nvim_win_close(self.win, true)
    end
    self.locked = false
    self.win = -1
    local source_buf = self.sidebar:source_win_buf()
    for _, key in ipairs(self.keymaps_to_remove) do
        vim.keymap.del("n", key, { buffer = source_buf })
    end
    self.keymaps_to_remove = {}
end

function Preview:goto_symbol()
    local cursor = vim.api.nvim_win_get_cursor(self.win)
    vim.api.nvim_win_set_cursor(self.sidebar.source_win, cursor)
    vim.api.nvim_set_current_win(self.sidebar.source_win)
    vim.fn.win_execute(self.sidebar.source_win, self.sidebar.unfold_on_goto and "normal! zz zv" or "normal! zz")
    if self.sidebar.close_on_goto then
        self.sidebar:close()
    end
end

---@type table<PreviewAction, fun(preview: Preview)>
local preview_actions = {
    ["close"] = Preview.close,
    ["goto-code"] = Preview.goto_symbol,
}
utils.assert_keys_are_enum(preview_actions, cfg.PreviewAction, "preview_actions")

function Preview:open()
    if vim.api.nvim_win_is_valid(self.win) then
        vim.api.nvim_set_current_win(self.win)
        return
    end

    local config = self.sidebar.preview_config
    local source_buf = self.sidebar:source_win_buf()
    local symbol = self.sidebar:current_symbol()
    local range = symbol.range
    local cursor = vim.api.nvim_win_get_cursor(self.sidebar.win)
    cursor[1] = cursor[1] - vim.fn.line("w0", self.sidebar.win) + 1

    local height = config.fixed_size_height
    if config.auto_size then
        height = config.auto_size_extra_lines + (range["end"].line - range.start.line) + 1
        height = math.max(config.min_window_height, height)
        height = math.min(config.max_window_height, height)
    end
    local max_height = vim.api.nvim_win_get_height(self.sidebar.source_win) - 3
    height = math.min(max_height, height)

    local max_width = vim.api.nvim_win_get_width(self.sidebar.source_win) - 2
    local width = config.window_width
    width = math.min(max_width, width)

    local opts = {
        height = height,
        width = width,
        border = "single",
        style = "minimal",
        zindex = 45, -- to allow other floating windows (like symbol peek) in front
    }
    if self.sidebar.win_dir == "right" then
        opts.relative = "win"
        opts.win = self.sidebar.win
        opts.anchor = "NE"
        opts.row = cursor[1] - 1
        opts.col = -1
    else
        opts.relative = "win"
        opts.win = self.sidebar.source_win
        opts.anchor = "NW"
        opts.row = cursor[1] - 1
        opts.col = 0
    end

    self.win = vim.api.nvim_open_win(source_buf, false, opts)
    if config.show_line_number then
        vim.wo[self.win].number = true
    end
    vim.api.nvim_win_set_cursor(
        self.win,
        { range.start.line+1, range.start.character }
    )
    vim.fn.win_execute(self.win, "normal! zt")
    vim.api.nvim_set_option_value("cursorline", true, { win = self.win })

    for keymap, action in pairs(config.keymaps) do
        local fn = function() preview_actions[action](self) end
        vim.keymap.set("n", keymap, fn, { buffer = source_buf })
        table.insert(self.keymaps_to_remove, keymap)
    end
end

function Preview:toggle_auto_show()
    if self.auto_show then self:close() else self:open() end
    self.auto_show = not self.auto_show
end

function Preview:on_cursor_move()
    -- After creating the preview the CursorMoved event is triggered once.
    -- We ignore it here.
    if self.locked then
        self.locked = false
    else
        self:close()
        if self.auto_show then self:open() end
    end
end

function Preview:on_win_enter()
    if (
        vim.api.nvim_win_is_valid(self.win) and
        vim.api.nvim_get_current_win() ~= self.win
    ) then
        self:close()
    end
end

---@param win integer
function Preview:on_win_close(win)
    if win == self.win then
        self:close()
    end
end

---@class DetailsWin
---@field sidebar Sidebar
---@field auto_show boolean
---@field win integer
---@field locked boolean
---@field prev_cursor [integer, integer] | nil
---@field show_debug_info boolean
local DetailsWin = {}
DetailsWin.__index = DetailsWin

---@return DetailsWin
function DetailsWin:new()
    return setmetatable({
        sidebar = nil,
        auto_show = false,
        win = -1,
        locked = false,
        prev_cursor = nil,
        show_debug_info = false
    }, self)
end

function DetailsWin:open()
    if vim.api.nvim_win_is_valid(self.win) then return end

    local sidebar_win = self.sidebar.win
    local symbols = self.sidebar:current_symbols()
    local symbol, symbol_state = self.sidebar:current_symbol()

    local details_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_option_value("bufhidden", "delete", { buf = details_buf })

    local text = {}

    if self.show_debug_info then
        ---@param range Range
        ---@return string
        local function range_string(range)
            return (
                "("
                .. "(" .. range.start.line .. ", " .. range.start.character .. "), "
                .. "(" .. range["end"].line .. ", " .. range["end"].character .. ")"
                .. ")"
            )
        end
        -- debug info
        table.insert(text, " [SYMBOL DEBUG INFO]")
        table.insert(text, "   name: " .. symbol.name)
        table.insert(text, "   kind: " .. (symbol.kind or ""))
        table.insert(text, "   level: " .. tostring(symbol.level))
        table.insert(text, "   parent: " .. symbol.parent.name)
        table.insert(text, "   range: " .. range_string(symbol.range))
        table.insert(text, "   folded: " .. tostring(symbol_state.folded))
        table.insert(text, "   visible: " .. tostring(symbol_state.visible))
        table.insert(text, "")
    end

    local ft = vim.api.nvim_get_option_value("ft", { buf = self.sidebar:source_win_buf() })
    local kinds_cfg = cfg.get_config_by_filetype(symbols.provider_config.kinds, ft)
    local highlights_cfg = cfg.get_config_by_filetype(symbols.provider_config.highlights, ft)

    ---@type Highlight[]
    local highlights = {}

    local display_kind = cfg.kind_for_symbol(kinds_cfg, symbol)
    if display_kind ~= "" then
        local highlight = nvim.Highlight:new({
            group = highlights_cfg[symbol.kind] or "",
            line = #text + 1,
            col_start = 1,
            col_end = 1 + #display_kind,
        })
        table.insert(highlights, highlight)
        display_kind = display_kind .. " "
    end
    table.insert(text, " " .. display_kind .. table.concat(Symbol_path(symbol), "."))

    if symbol.detail ~= "" then
        local detail_first_line = #text + 1
        for detail_line, line in ipairs(vim.split(symbol.detail, "\n")) do
            table.insert(text, "   " .. line)
            table.insert(highlights, nvim.Highlight:new({
                group = "Comment",
                line = detail_first_line + detail_line - 1,
                col_start = 0,
                col_end = 3 + #line,
            }))
        end
    end

    local longest_line = 0
    for _, line in ipairs(text) do
        longest_line = math.max(longest_line, #line)
    end

    nvim.buf_set_content(details_buf, text)
    buf_add_highlights(details_buf, highlights)

    local line_count = vim.api.nvim_buf_line_count(details_buf)

    local sidebar_width = vim.api.nvim_win_get_width(sidebar_win)
    local width = math.max(sidebar_width - 2, longest_line + 1)
    local height = line_count

    local cursor = vim.api.nvim_win_get_cursor(sidebar_win)
    cursor[1] = cursor[1] - vim.fn.line("w0", sidebar_win) + 1

    local row = cursor[1] - 3 - height
    if row < 0 then row = cursor[1] end

    local col = 0
    if self.sidebar.win_dir == "right" and width + 2 > sidebar_width then
        col = col - (width + 2 - sidebar_width)
    end

    local opts = {
        relative = "win",
        win = self.sidebar.win,
        anchor = "NW",
        row = row,
        col = col,
        width = width,
        height = height,
        border = "single",
        style = "minimal",
    }
    self.win = vim.api.nvim_open_win(details_buf, false, opts)
end

function DetailsWin:on_cursor_move()
    if self.locked then
        if self.prev_cursor ~= nil then
            vim.api.nvim_win_set_cursor(self.sidebar.win, self.prev_cursor)
            self.prev_cursor = nil
        end
        self.locked = false
    else
        if vim.api.nvim_win_is_valid(self.win) then
            vim.api.nvim_win_close(self.win, true)
            self.win = -1
        end
        if self.auto_show then
            self:open()
        end
    end
end

function DetailsWin:close()
    if vim.api.nvim_win_is_valid(self.win) then
        vim.api.nvim_win_close(self.win, true)
    end
    self.win = -1
    self.locked = false
end

function DetailsWin:toggle_auto_show()
    if self.auto_show then self:close() else self:open() end
    self.auto_show = not self.auto_show
end

function DetailsWin:on_win_enter()
    if vim.api.nvim_win_is_valid(self.win) then
        local curr_win = vim.api.nvim_get_current_win()
        if curr_win == self.sidebar.win then
            if self.auto_show then
                self:open()
            end
        else
            self:close()
        end
    end
end

---@class CursorState
---@field hide boolean
---@field hidden boolean
---@field original string

---@class GlobalSettings
---@field open_direction OpenDirection
---@field on_open_make_windows_equal boolean

---@class GlobalState
---@field cursor CursorState
---@field settings GlobalSettings

---@return GlobalState
local function GlobalState_new()
    ---@type GlobalState
    local obj = {
        cursor = {
            hide = false,
            hidden = false,
            original = vim.o.guicursor,
        },
        settings = {
            open_direction = cfg.default.sidebar.open_direction,
            on_open_make_windows_equal = cfg.default.sidebar.on_open_make_windows_equal,
        },
    }
    return obj
end

---@class SymbolState
---@field folded boolean
---@field visible boolean
---@field visible_children integer

---@return SymbolState
local function SymbolState_new()
    return {
        folded = true,
        visible = true,
        visible_children = 0,
    }
end

---@alias SymbolStates table<Symbol, SymbolState>

---@param root Symbol
---@return Symbols
local function SymbolStates_build(root)
    local states = {}

    local function traverse(symbol)
        states[symbol] = SymbolState_new()
        for _, child in ipairs(symbol.children) do
            traverse(child)
        end
    end

    traverse(root)
    return states
end

---@alias SymbolFilter fun(ft: string, symbol: Symbol): boolean

---@class Symbols
---@field provider string
---@field provider_config table
---@field buf integer
---@field root Symbol
---@field states SymbolStates
---@field any_nesting boolean

---@return Symbols
local function Symbols_new()
    local root = Symbol_root()
    local symbols = {
        provider = "",
        buf = -1,
        root = root,
        states = {
            [root] = SymbolState_new()
        },
        any_nesting = false,
    }
    symbols.states[root].folded = false
    return symbols
end

---@param symbols Symbols
---@param symbol_filter SymbolFilter
local function Symbols_apply_filter(symbols, symbol_filter)
    local ft = vim.api.nvim_get_option_value("filetype", { buf = symbols.buf })
    symbols.any_nesting = false

    ---@param symbol Symbol
    local function apply(symbol)
        local state = symbols.states[symbol]
        if symbol.level == 0 then
            state.visible = true
        else
            state.visible = symbol_filter(ft, symbol)
        end
        state.visible_children = 0
        for _, child in ipairs(symbol.children) do
            apply(child)
            if symbols.states[child].visible then
                state.visible_children = state.visible_children + 1
            end
        end

        if state.visible_children > 0 and symbol.level == 1 then
            symbols.any_nesting = true
        end

    end

    apply(symbols.root)
end

---@class SymbolsCacheEntry
---@field root Symbol
---@field fresh boolean
---@field update_in_progress boolean
---@field post_update_callbacks RefreshSymbolsFun[]
---@field updated osdate
---@field provider_name string

---@return SymbolsCacheEntry
local function SymbolsCacheEntry_new()
    return {
        root = Symbol_root(),
        fresh = false,
        update_in_progress = false,
        post_update_callbacks = {},
        updated = nil,
        provider_name = ""
    }
end

---@alias SymbolsCache table<integer, SymbolsCacheEntry>

---@return SymbolsCache
local function SymbolsCache_new()
    return vim.defaulttable(SymbolsCacheEntry_new)
end

---@class SymbolsRetriever
---@field providers [string, any][] type(Provider)[]
---@field providers_config ProvidersConfig
---@field cache SymbolsCache

---@param providers Provider[]
---@param providers_config ProvidersConfig
---@return SymbolsRetriever
local function SymbolsRetriever_new(providers, providers_config)
    return {
        providers = providers,
        providers_config = providers_config,
        cache = SymbolsCache_new()
    }
end

---@param retriever SymbolsRetriever
---@param buf integer
---@param on_retrieve fun(symbol: Symbol, provider_name: string, provider_config: table)
---@param on_fail fun(provider_name: string)
---@param on_timeout fun(provider_name: string)
---@return boolean
local function SymbolsRetriever_retrieve(retriever, buf, on_retrieve, on_fail, on_timeout)
    local function cleanup_on_fail()
        local entry = retriever.cache[buf]
        entry.update_in_progress = false
        entry.post_update_callbacks = {}
    end

    ---@param provider_name string
    local function _on_fail(provider_name)
        return function()
            cleanup_on_fail()
            log.warn(provider_name .. " failed")
            on_fail(provider_name)
        end
    end

    ---@param provider_name string
    local function _on_timeout(provider_name)
        return function()
            cleanup_on_fail()
            log.warn(provider_name .. " timed out")
            on_timeout(provider_name)
        end
    end

    ---@param provider_name string
    ---@param cached boolean
    ---@return fun(root: Symbol)
    local _on_retrieve = function(provider_name, cached)
        ---@param root Symbol
        return function(root)
            local entry = retriever.cache[buf]
            entry.root = root
            entry.fresh = true
            if not cached then
                local date = os.date("*t")
                assert(type(date) ~= "string")
                entry.updated = date
            end
            entry.provider_name = provider_name

            for _, callback in ipairs(entry.post_update_callbacks) do
                callback(root, provider_name, retriever.providers_config[provider_name])
            end

            entry.update_in_progress = false
            entry.post_update_callbacks = {}
        end
    end

    local entry = retriever.cache[buf]

    if entry.fresh then
        log.trace("entry fresh, running _on_retrieve and quiting")
        table.insert(entry.post_update_callbacks, on_retrieve)
        _on_retrieve(entry.provider_name, true)(entry.root)
        return true
    end

    if entry.update_in_progress then
        log.trace("update in progress, adding callback and quiting")
        -- TODO: do not add multiple callbacks for the same sidebar
        table.insert(entry.post_update_callbacks, on_retrieve)
        return true
    end

    log.trace("attempting to retrieve symbols")
    for _, _provider in ipairs(retriever.providers) do
        local provider_name = _provider[1]
        local config = retriever.providers_config[provider_name]
        ---@type Provider
        local provider = _provider[2]:new(config)
        if provider:supports(buf) then
            log.trace("using provider: " .. provider_name)
            table.insert(entry.post_update_callbacks, on_retrieve)
            entry.update_in_progress = true
            if provider.async_get_symbols ~= nil then
                provider:async_get_symbols(
                    buf,
                    _on_retrieve(provider_name, false),
                    _on_fail(provider_name),
                    _on_timeout(provider_name)
                )
            else
                local ok, symbol = provider:get_symbols(buf)
                if not ok then
                    _on_fail(provider_name)()
                else
                    assert(symbol ~= nil)
                    _on_retrieve(provider_name, false)(symbol)
                end
            end
            return true
        end
    end
    return false
end

---@class WinSettings
---@field number boolean | nil
---@field relativenumber boolean | nil
---@field signcolumn string | nil
---@field cursorline boolean | nil
---@field winfixwidth boolean | nil
---@field wrap boolean | nil

---@return WinSettings
local function WinSettings_new()
    return {
        number = nil,
        relativenumber = nil,
        signcolumn = nil,
        cursorline = nil,
        winfixwidth = nil,
        wrap = nil,
    }
end

---@param win integer
---@return WinSettings
local function WinSettings_get(win)
    ---@param opt string
    local function get_opt(opt)
        return vim.api.nvim_get_option_value(opt, { win = win })
    end
    ---@type WinSettings
    local settings = {
        number = get_opt("number"),
        relativenumber = get_opt("relativenumber"),
        signcolumn = get_opt("signcolumn"),
        cursorline = get_opt("cursorline"),
        winfixwidth = get_opt("winfixwidth"),
        wrap = get_opt("wrap")
    }
    return settings
end

---@param win integer
---@param settings WinSettings
local function WinSettings_apply(win, settings)
    ---@param name string
    ---@param value any
    local function set_opt(name, value)
        vim.api.nvim_set_option_value(name, value, { win = win })
    end
    for opt_name, opt_value in pairs(settings) do
        if opt_value ~= nil then
            set_opt(opt_name, opt_value)
        end
    end
end

---@param cursor CursorState
local function activate_cursorline(cursor)
    if not cursor.hidden then
        local cur = vim.o.guicursor:match("n.-:(.-)[-,]")
        -- There is at least one report of cur being equal nil.
        -- Until we figure out why that happens, let's just continue in that case.
        if cur == nil then
            local msg = string.format("Unexpected guicursor value: '%s'", vim.o.guicursor)
            log.warn(msg)
        else
            vim.opt.guicursor:append("n:" .. cur .. "-Cursorline")
        end
        cursor.hidden = true
    end
end

---@param sidebar Sidebar
local function hide_cursor(sidebar)
    local pos = vim.api.nvim_win_get_cursor(sidebar.win)
    local any_nesting = sidebar:current_symbols().any_nesting
    local col = (any_nesting and 1) or 0
    if col ~= pos[2] then
        vim.api.nvim_win_set_cursor(sidebar.win, { pos[1], col })
    end
end

---@param cursor CursorState
local function reset_cursor(cursor)
    vim.o.guicursor = cursor.original
    cursor.hidden = false
end

---@class (exact) SearchView
---@field sidebar Sidebar
---@field buf integer
---@field prompt_buf integer
---@field prompt_win integer
---@field search_results SearchSymbol[]
---@field flat_symbols Symbol[]
---@field history string[]
---@field history_idx integer
local SearchView = {}
---@diagnostic disable-next-line
SearchView.__index = SearchView

---@return SearchView
function SearchView:new()
    return setmetatable({
        sidebar = nil,
        buf = -1,
        prompt_buf = -1,
        prompt_win = -1,
        search_results = {},
        flat_symbols = {},
        history = {},
        history_idx = -1
    }, self)
end

function SearchView:init(sidebar)
    self.sidebar = sidebar
    self:init_buf()
    self:init_prompt_buf()
end

function SearchView:init_buf()
    if vim.api.nvim_buf_is_valid(self.buf) then return end

    self.buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(self.buf, "symbols.nvim [" .. tostring(self.sidebar.num) .. "]" .. " (search)")
    vim.api.nvim_buf_set_option(self.buf, "filetype", M.FILE_TYPE_SEARCH)
    nvim.buf_set_modifiable(self.buf, false)

    vim.api.nvim_create_autocmd(
        { "WinResized" },
        {
            group = global_autocmd_group,
            callback = function()
                if self.prompt_win == -1 then return end
                local win = self.sidebar.win
                local win_h = vim.api.nvim_win_get_height(win)
                local win_w = vim.api.nvim_win_get_width(win)
                local opts = {
                    relative = "win",
                    win = self.sidebar.win,
                    height = 1,
                    width = win_w - 1,
                    row = win_h - 2,
                    col = 0,
                }
                vim.api.nvim_win_set_config(self.prompt_win, opts)
            end,
        }
    )

    vim.keymap.set(
        "n", "q",
        function() self.sidebar:close() end,
        { buffer = self.buf }
    )
    vim.keymap.set(
        "n", "o",
        function()
            self:save_history()
            self:jump_to_current_symbol()
            vim.api.nvim_set_current_win(self.sidebar.win)
        end,
        { buffer = self.buf }
    )
end

function SearchView:init_prompt_buf()
    if vim.api.nvim_buf_is_valid(self.prompt_buf) then return end
    self.prompt_buf = vim.api.nvim_create_buf(false, true)

    vim.api.nvim_create_autocmd(
        { "TextChangedI" },
        {
            group = global_autocmd_group,
            buffer = self.prompt_buf,
            callback = function() self:search() end,
        }
    )
    --- TODO remove this autocommand when no longer needed
    vim.api.nvim_create_autocmd(
        { "WinEnter" },
        {
            group = global_autocmd_group,
            callback = function()
                local win = vim.api.nvim_get_current_win()
                if win == self.prompt_win then
                    vim.cmd("startinsert!")
                end
            end
        }
    )
    vim.api.nvim_create_autocmd(
        { "WinLeave" },
        {
            group = global_autocmd_group,
            callback = function()
                local win = vim.api.nvim_get_current_win()
                if win == self.prompt_win then
                    vim.cmd("stopinsert")
                end
            end
        }
    )
    vim.api.nvim_create_autocmd(
        { "BufHidden" },
        {
            group = global_autocmd_group,
            buffer = self.prompt_buf,
            callback = function() self:hide() end
        }
    )

    vim.keymap.set(
        "i", "<Esc>",
        function()
            vim.api.nvim_set_current_win(self.sidebar.win)
        end,
        { buffer = self.prompt_buf }
    )
    vim.keymap.set(
        "i", "<S-Tab>",
        function()
            local cursor = vim.api.nvim_win_get_cursor(self.sidebar.win)
            local new_cursor = { cursor[1] - 1, 0 }
            if new_cursor[1] == 0 then
                local lines = vim.api.nvim_buf_line_count(self.buf)
                new_cursor[1] = lines
            end
            vim.api.nvim_win_set_cursor(self.sidebar.win, new_cursor)
        end,
        { buffer = self.prompt_buf }
    )
    vim.keymap.set(
        "i", "<Tab>",
        function()
            local cursor = vim.api.nvim_win_get_cursor(self.sidebar.win)
            local new_cursor = { cursor[1] + 1, 0 }
            local lines = vim.api.nvim_buf_line_count(self.buf)
            if new_cursor[1] > lines then new_cursor[1] = 1 end
            vim.api.nvim_win_set_cursor(self.sidebar.win, new_cursor)
        end,
        { buffer = self.prompt_buf }
    )
    vim.keymap.set(
        "i", "<Cr>",
        function()
            self:save_history()
            self:jump_to_current_symbol()
            if self.sidebar.close_on_goto then
                self.sidebar:close()
            else
                self.sidebar:change_view("symbols")
            end
        end,
        { buffer = self.prompt_buf }
    )
    vim.keymap.set(
        "i", "<C-j>",
        function()
            local text = self:next_item_from_history()
            self:set_prompt_buf(text)
        end,
        { buffer = self.prompt_buf }
    )
    vim.keymap.set(
        "i", "<C-k>",
        function()
            local text = self:prev_item_from_history()
            self:set_prompt_buf(text)
        end,
        { buffer = self.prompt_buf }
    )
end

---@param value string
function SearchView:set_prompt_buf(value)
    value = " " .. value
    vim.api.nvim_buf_set_lines(self.prompt_buf, 0, -1, false, { value })
    if vim.api.nvim_win_is_valid(self.prompt_win) then
        vim.api.nvim_win_set_cursor(self.prompt_win, { 1, #value })
    end
end

function SearchView:clear_prompt_buf()
    self:set_prompt_buf("")
    self.history_idx = -1
end

function SearchView:show_prompt_win()
    self:clear_prompt_buf()

    local win = self.sidebar.win
    local win_h = vim.api.nvim_win_get_height(win)
    local win_w = vim.api.nvim_win_get_width(win)
    local opts = {
        height = 1,
        width = win_w - 1,
        border = { "", "", "", "", "", "", "", ">" },
        style = "minimal",
        relative = "win",
        win = win,
        anchor = "NW",
        row = win_h - 2,
        col = 0,
    }
    self.prompt_win = vim.api.nvim_open_win(self.prompt_buf, false, opts)
end

---@return string
function SearchView:get_prompt_text()
    local text = vim.api.nvim_buf_get_lines(self.prompt_buf, 0, 1, false)[1]
    return vim.trim(text)
end

function SearchView:save_history()
    local text = self:get_prompt_text()
    if self.history[#self.history] ~= text then
        table.insert(self.history, text)
    end
end

---@return string
function SearchView:prev_item_from_history()
    assert(self.history_idx < #self.history, "SearchView.history_idx too large")
    if #self.history == 0 then return "" end
    if self.history_idx + 1 == #self.history then
        return self.history[1]
    end
    self.history_idx = self.history_idx + 1
    return self.history[#self.history - self.history_idx]
end

---@return string
function SearchView:next_item_from_history()
    if self.history_idx <= 0 then
        self.history_idx = -1
        return ""
    end
    self.history_idx = self.history_idx - 1
    return self.history[#self.history - self.history_idx]
end

---@class (exact) SearchSymbol
---@field s string
---@field i integer

---@return SearchSymbol[], Symbol[]
local function _prepare_symbols_for_search(symbols, ft)
    local search_symbols = {}
    local flat_symbols = {}
    local kinds = cfg.get_config_by_filetype(symbols.provider_config.kinds, ft)
    local function _prepare(symbol)
        if not symbols.states[symbol].visible then return end
        if symbol.level > 0 then
            local kind = cfg.kind_for_symbol(kinds, symbol)
            local search_str = " " .. kind .. " " .. symbol.name
            ---@type SearchSymbol
            local search_symbol = { s = search_str, i = #flat_symbols+1 }
            table.insert(search_symbols, search_symbol)
            table.insert(flat_symbols, symbol)
        end
        for _, child in ipairs(symbol.children) do
            _prepare(child)
        end
    end
    _prepare(symbols.root)
    return search_symbols, flat_symbols
end

---@param symbols SearchSymbol[]
---@return string[]
local function _search_symbols_to_lines(symbols)
    local buf_lines = {}
    for _, symbol in ipairs(symbols) do
        table.insert(buf_lines, symbol.s)
    end
    return buf_lines
end

---@param search_symbols SearchSymbol[]
---@param flat_symbols Symbol[]
---@return Highlight[]
function SearchView:_search_symbols_highlights(search_symbols, flat_symbols)
    local highlights = {} ---@type Highlight[]
    local symbols = self.sidebar:current_symbols()
    local ft = vim.api.nvim_get_option_value("filetype", { buf = symbols.buf })
    local highlights_config = cfg.get_config_by_filetype(symbols.provider_config.highlights, ft)
    local kinds_display_config = cfg.get_config_by_filetype(symbols.provider_config.kinds, ft)
    local kinds_default_config = symbols.provider_config.kinds.default
    for line_nr, search_symbol in ipairs(search_symbols) do
        local symbol = flat_symbols[search_symbol.i]
        local kind_display = cfg.kind_for_symbol(kinds_display_config, symbol, kinds_default_config)
        local highlight = nvim.Highlight:new({
            group = highlights_config[symbol.kind] or "",
            line = line_nr,
            col_start = 1,
            col_end = #kind_display + 1,
        })
        table.insert(highlights, highlight)
    end
    return highlights
end

function SearchView:search()
    local text = self:get_prompt_text()
    local symbols = self.sidebar:current_symbols()
    local source_buf = self.sidebar:source_win_buf()
    local ft = vim.api.nvim_get_option_value("filetype", { buf = source_buf })
    local search_symbols
    search_symbols, self.flat_symbols = _prepare_symbols_for_search(symbols, ft)
    local buf_lines = {}
    local highlights = {}
    if #text == 0 then
        buf_lines = _search_symbols_to_lines(search_symbols)
        highlights = self:_search_symbols_highlights(search_symbols, self.flat_symbols)
    else
        self.search_results = vim.fn.matchfuzzy(search_symbols, text, { key = "s" })
        buf_lines = _search_symbols_to_lines(self.search_results)
        highlights = self:_search_symbols_highlights(self.search_results, self.flat_symbols)
    end
    if #buf_lines == 0 then table.insert(buf_lines, "") end
    nvim.buf_set_content(self.buf, buf_lines)
    for _, highlight in ipairs(highlights) do highlight:apply(self.buf) end
    vim.api.nvim_win_set_cursor(self.sidebar.win, { 1, 0 })
end

function SearchView:hide()
    if vim.api.nvim_win_is_valid(self.prompt_win) then
        vim.cmd("stopinsert")
        vim.api.nvim_win_close(self.prompt_win, true)
        self.prompt_win = -1
    end
end

function SearchView:jump_to_current_symbol()
    local cursor = vim.api.nvim_win_get_cursor(self.sidebar.win)
    local search_symbol = self.search_results[cursor[1]]
    local symbol = self.flat_symbols[search_symbol.i]
    vim.api.nvim_win_set_cursor(
        self.sidebar.source_win,
        { symbol.range.start.line + 1, symbol.range.start.character }
    )
    vim.api.nvim_set_current_win(self.sidebar.source_win)
    vim.fn.win_execute(self.sidebar.source_win, self.sidebar.unfold_on_goto and "normal! zz zv" or "normal! zz")
    flash_highlight_under_cursor(self.sidebar.source_win, 400, 1)
end

function SearchView:show_prompt()
    self:show_prompt_win()

    vim.keymap.set(
        "n", "s",
        function()
            vim.api.nvim_set_current_win(self.prompt_win)
        end,
        { buffer = self.buf }
    )
    vim.keymap.set(
        "n", "<Esc>",
        function()
            self.sidebar:change_view("symbols")
        end,
        { buffer = self.buf }
    )
    vim.keymap.set(
        "n", "<Cr>",
        function()
            self:save_history()
            self:jump_to_current_symbol()
            if self.sidebar.close_on_goto then
                self.sidebar:close()
            else
                self.sidebar:change_view("symbols")
            end
        end,
        { buffer = self.buf }
    )

    vim.api.nvim_set_current_win(self.prompt_win)
    vim.cmd("startinsert!")
end

function SearchView:show()
    vim.api.nvim_win_set_buf(self.sidebar.win, self.buf)
    self:show_prompt()
end

function SearchView:destroy()
    if vim.api.nvim_buf_is_valid(self.buf) then
        vim.api.nvim_buf_delete(self.buf, { force = true })
        self.buf = -1
    end
    if vim.api.nvim_buf_is_valid(self.prompt_buf) then
        vim.api.nvim_buf_delete(self.prompt_buf, { force = true })
        self.prompt_buf = -1
    end
end

---@alias SidebarView "symbols" | "search"

---@class (exact) Sidebar
---@field num integer Ordering number, used for naming buffers.
---@field gs GlobalState
---@field deleted boolean
---@field win integer
---@field win_dir "left" | "right"
---@field win_settings WinSettings
---@field current_view SidebarView
---@field search_view SearchView
---@field buf integer
---@field source_win integer
---@field symbols_retriever SymbolsRetriever
---@field buf_symbols table<integer, Symbols>
---@field symbol_display_config table<string, SymbolDisplayConfig>
---@field preview_config PreviewConfig
---@field preview Preview
---@field details DetailsWin
---@field char_config CharConfig
---@field show_inline_details boolean
---@field show_guide_lines boolean
---@field wrap boolean
---@field unfold_on_goto boolean
---@field auto_resize AutoResizeConfig
---@field fixed_width integer
---@field keymaps KeymapsConfig
---@field symbol_filters_enabled boolean
---@field symbol_filter SymbolFilter
---@field cursor_follow boolean
---@field auto_peek boolean
---@field close_on_goto boolean
---@field resize_callback_running boolean
---@field resize_last_schedule_ms number
---@field resize_ignore_next boolean
local Sidebar = {}
Sidebar.__index = Sidebar ---@diagnostic disable-line

---@return Sidebar
function Sidebar:new()
    local config = cfg.default.sidebar
    ---@type Sidebar
    local s = {
        num = -1,
        gs = GlobalState_new(),
        deleted = false,
        win = -1,
        win_dir = "right",
        win_settings = WinSettings_new(),
        current_view = "symbols",
        search_view = SearchView:new(),
        buf = -1,
        source_win = -1,
        symbols_retriever = nil, ---@diagnostic disable-line
        symbols_cache = SymbolsCache_new(),
        buf_symbols = vim.defaulttable(Symbols_new),
        symbol_display_config = {},
        preview_config = config.preview,
        preview = Preview:new(),
        details = DetailsWin:new(),
        char_config = config.chars,
        show_inline_details = false,
        show_guide_lines = false,
        wrap = false,
        unfold_on_goto = config.unfold_on_goto,
        auto_resize = vim.deepcopy(config.auto_resize, true),
        fixed_width = config.fixed_width,
        keymaps = config.keymaps,
        symbol_state = {},
        symbol_filters_enabled = true,
        symbol_filter = config.symbol_filter,
        cursor_follow = config.cursor_follow,
        auto_peek = config.auto_peek,
        close_on_goto = config.close_on_goto,
        resize_callback_running = false,
        resize_last_schedule_ms = relative_time_ms(),
        resize_ignore_next = false,
    }
    return setmetatable(s, self)

end

---@return boolean
function Sidebar:visible()
    return self.win ~= -1
end

---@return integer
function Sidebar:source_win_buf()
    if vim.api.nvim_win_is_valid(self.source_win) then
        return vim.api.nvim_win_get_buf(self.source_win)
    end
    return -1
end

---@param new_view SidebarView
function Sidebar:change_view(new_view)
    if self.current_view == "symbols" then
    elseif self.current_view == "search" then
        self.search_view:hide()
    else
        assert(false, "Unknown view: " .. tostring(self.current_view))
    end

    if new_view == "symbols" then
        vim.api.nvim_win_set_buf(self.win, self.buf)
    elseif new_view == "search" then
        self.search_view:show()
    else
        assert(false, "Unknown view: " .. tostring(new_view))
    end

    self.current_view = new_view
end

---@param root Symbol
---@param pos Pos
---@return Symbol
local function symbol_at_pos(root, pos)

    ---@param range Range
    ---@param _pos Pos
    ---@return boolean
    local function in_range_line(range, _pos)
        return range.start.line <= _pos.line and _pos.line <= range["end"].line
    end

    ---@param range Range
    ---@param _pos Pos
    ---@return boolean
    local function in_range_character(range, _pos)
        return range.start.character <= _pos.character and _pos.character <= range["end"].character
    end

    ---@param range Range
    ---@param _pos Pos
    ---@return boolean
    local function range_before_pos(range, _pos)
        return (
            range["end"].line < _pos.line
            or (
                range["end"].line == _pos.line
                and range["end"].character < _pos.line
            )
        )
    end

    local current = root
    local partial_match = true
    while #current.children > 0 and partial_match do
        partial_match = false
        local prev = current
        for _, symbol in ipairs(current.children) do
            if range_before_pos(symbol.range, pos) then
                prev = symbol
            end
            if not partial_match and in_range_line(symbol.range, pos) then
                current = symbol
                partial_match = true
            end
            if partial_match then
                if in_range_line(symbol.range, pos) then
                    if in_range_character(symbol.range, pos) then
                        current = symbol
                        break
                    end
                else
                    break
                end
            end
        end
        if not partial_match then current = prev end
    end
    return current
end

---@return Symbols
function Sidebar:current_symbols()
    local source_buf = self:source_win_buf()
    if source_buf == -1 then return Symbols_new() end
    local symbols = self.buf_symbols[source_buf]
    symbols.buf = source_buf
    return symbols
end

---@param symbols Symbols
function Sidebar:replace_current_symbols(symbols)
    assert(symbols.buf ~= -1, "symbols.buf has to be set")
    self.buf_symbols[symbols.buf] = symbols
end

---@return string
function Sidebar:to_string()
    local tab = -1
    if vim.api.nvim_win_is_valid(self.win) then
        tab = vim.api.nvim_win_get_tabpage(self.win)
    end

    local buf_name = ""
    if vim.api.nvim_buf_is_valid(self.buf) then
        buf_name = " (" .. vim.api.nvim_buf_get_name(self.buf) .. ")"
    end

    local source_win_buf = -1
    local source_win_buf_name = ""
    if vim.api.nvim_win_is_valid(self.source_win) then
        source_win_buf = vim.api.nvim_win_get_buf(self.source_win)
        source_win_buf_name = vim.api.nvim_buf_get_name(source_win_buf)
        if source_win_buf_name == "" then
            source_win_buf_name = " <scratch buffer>"
        else
            source_win_buf_name = " (" .. source_win_buf_name .. ")"
        end
    end

    local lines = {
        "Sidebar(",
        "  deleted: " .. tostring(self.deleted),
        "  visible: " .. tostring(self:visible()),
        "  tab: " .. tostring(tab),
        "  win: " .. tostring(self.win),
        "  buf: " .. tostring(self.buf) .. buf_name,
        "  source_win: " .. tostring(self.source_win),
        "  source_win_buf: " .. tostring(source_win_buf) .. source_win_buf_name,
        "  buf_symbols: {",
    }

    for buf, root_symbol in pairs(self.buf_symbols) do
        local _buf_name = vim.api.nvim_buf_get_name(buf)
        local symbols_count_string = " (no symbols)"
        local symbols_count = #root_symbol.root.children
        if symbols_count > 0 then
            symbols_count_string = " (" .. tostring(symbols_count) .. "+ symbols)"
        end

        local line = "    \"" .. buf .. "\" (" .. _buf_name .. ") " .. symbols_count_string
        table.insert(lines, line)
    end

    table.insert(lines, "  }")
    table.insert(lines, ")")
    return table.concat(lines, "\n")
end

---@param vert_size integer
function Sidebar:change_size(vert_size)
    vim.api.nvim_win_set_width(self.win, vert_size)
end

--- TODO: consider using a config option for this
--- Refreshing size uses the currently visible lines to adjust the sidebar window width.
--- This constant allows to adjust the number of additional lines that will be taken
--- into account. More precisely, it's the number of extra lines preceeding and suceeding the visible
--- lines that will be considered for resizing. Setting this number to 0 would make resizing the most
--- responsive but also jerky as it would adjust every time the sidebar is scrolled. Setting it
--- to a big enough value removes the jerkiness and is still fast. Setting it to a too high of
--- a value will cause slow downs but remove any "unnecessary" resizing.
local REFRESH_SIZE_CONTEXT_LEN = 5000

function Sidebar:refresh_size()
    if not self:visible() or not self.auto_resize.enabled then return end
    local buf_lines = nvim.win_get_visible_lines(self.win, REFRESH_SIZE_CONTEXT_LEN, REFRESH_SIZE_CONTEXT_LEN)
    local vert_resize = self.fixed_width
    local max_line_len = 0
    for _, line in ipairs(buf_lines) do
        max_line_len = math.max(max_line_len, #line)
    end
    vert_resize = max_line_len + 1
    vert_resize = math.max(self.auto_resize.min_width, vert_resize)
    vert_resize = math.min(self.auto_resize.max_width, vert_resize)
    self:change_size(vert_resize)
end

-- After this many ms of inactivity (no Sidebar.schedule_refresh_size calls) the sidebar will refresh its size
-- Too small of a value will cause repeated size refreshing when performing many quick actions, e.g. imagine
-- someone folding and unfolding a symbol multiple times in a quick succession. Resizing can be slow when there
-- are large files open in the same tab, so it's better to not refresh all the time.
local DELAY_MS_SIZE_REFRESH = 100

-- Every this many ms a function will run to check when the Sidebar.schedule_refresh_size function was called
-- and decide whether to refresh the sidebar size. After refreshing the size it will no longer run until
-- the Sidebar.schedule_refresh_size function is called again.
-- Small values will give fast response time, too small of a value can cause slow downs.
local PERIOD_MS_SIZE_REFRESH_CHECK = 32

-- Refreshing size is slow for large files, thus for quick actions it's advised to use this function
-- instead of refreshing the size immediately. Otherwise, we the user can easily trigger multiple size
-- refreshes in short time which are redundant (and slow). This function will refresh the size after
-- DELAY_MS_SIZE_REFRESH miliseconds of inactivity (no calls to this function) with
-- PERIOD_MS_SIZE_REFRESH_CHECK precision.
function Sidebar:schedule_refresh_size()
    -- This is needed because changing size triggers WinScrolled event which calls this function.
    -- Without ignoring that call we would be constatly scheduling size refresh.
    if self.resize_ignore_next then
        self.resize_ignore_next = false
        return
    end

    self.resize_last_schedule_ms = relative_time_ms()
    if self.resize_callback_running then return end
    self.resize_callback_running = true

    local timer = vim.uv.new_timer()
    timer:start(
        PERIOD_MS_SIZE_REFRESH_CHECK, PERIOD_MS_SIZE_REFRESH_CHECK,
        function()
            local now_ms = relative_time_ms()
            local diff_ms = now_ms - self.resize_last_schedule_ms
            if diff_ms > DELAY_MS_SIZE_REFRESH then
                vim.schedule(function() self:refresh_size() end)
                self.resize_callback_running = false
                self.resize_ignore_next = true
                timer:stop()
                timer:close()
            end
        end,
        { ["repeat"] = -1 }
    )
end

---@param dir OpenDirection
---@return "left" | "right"
local function find_split_direction(dir)
    if dir == "left" or dir == "right" then
        ---@diagnostic disable-next-line
        return dir
    end

    -- TODO: ignore floating windows?
    local wins = vim.api.nvim_tabpage_list_wins(0)
    local curr_win = vim.api.nvim_get_current_win()
    if dir == "try-left" then
        return (wins[1] == curr_win and "left") or "right"
    elseif dir == "try-right" then
        return (wins[#wins] == curr_win and "right") or "left"
    end

    ---@diagnostic disable-next-line
    assert(false, "invalid dir")
end

---@return integer, "left" | "right"
function Sidebar:open_bare_win()
    local dir = find_split_direction(self.gs.settings.open_direction)
    local width = self.fixed_width
    local dir_cmd = (dir == "left" and "leftabove") or "rightbelow"
    vim.cmd("vertical " .. dir_cmd .. " " .. tostring(width) .. "split")
    return vim.api.nvim_get_current_win(), dir
end

function Sidebar:open()
    if self:visible() then return end

    local original_win = vim.api.nvim_get_current_win()
    vim.api.nvim_set_current_win(self.source_win)
    self.win, self.win_dir = self:open_bare_win()
    vim.api.nvim_set_current_win(original_win)
    vim.api.nvim_win_set_buf(self.win, self.buf)

    self.win_settings = WinSettings_get(self.win)
    WinSettings_apply(
        self.win,
        {
            number = false,
            relativenumber = false,
            signcolumn = "no",
            cursorline = true,
            winfixwidth = true,
            foldcolumn = "0",
            statuscolumn = "",
            listchars = "eol: ",
            wrap = self.wrap,
        }
    )

    self:change_size(self.fixed_width)
    self:refresh_size()
    if self.gs.settings.on_open_make_windows_equal then
        vim.cmd("wincmd =")
    end
end

local function symbols_view_close(sidebar)
    sidebar.preview:close()
    sidebar.details:close()
end

--- Restore window state to default. Useful when opening a file in the sidebar window.
function Sidebar:win_restore()
    symbols_view_close(self)
    self.search_view:hide()
    WinSettings_apply(self.win, self.win_settings)
    reset_cursor(self.gs.cursor)
    self.win = -1
    vim.cmd("wincmd =")
end

function Sidebar:close()
    if not self:visible() then return end
    symbols_view_close(self)
    self.search_view:hide()
    if vim.api.nvim_win_is_valid(self.win) then
        vim.api.nvim_win_close(self.win, true)
        self.win = -1
    end
end

function Sidebar:destroy()
    self:close()
    if vim.api.nvim_buf_is_valid(self.buf) then
        vim.api.nvim_buf_delete(self.buf, { force = true })
        self.buf = -1
    end
    self.search_view:destroy()
    self.source_win = -1
    self.deleted = true
end

---@return Symbol, SymbolState
function Sidebar:current_symbol()
    assert(vim.api.nvim_win_is_valid(self.win))

    local symbols = self:current_symbols()

    ---@param symbol Symbol
    ---@param num integer
    ---@return Symbol, integer
    local function _find_symbol(symbol, num)
        if num == 0 then return symbol, 0 end
        if symbols.states[symbol].folded then
            return symbol, num
        end
        for _, sym in ipairs(symbol.children) do
            if symbols.states[sym].visible then
                local s
                s, num = _find_symbol(sym, num - 1)
                if num <= 0 then return s, 0 end
            end
        end
        return symbol, num
    end

    local line = vim.api.nvim_win_get_cursor(self.win)[1]
    local s, _ = _find_symbol(symbols.root, line)
    return s, symbols.states[s]
end

---@class (exact) DisplayContext
---@field symbols Symbols
---@field ft string
---@field kind_display_config table
---@field kind_default_config table
---@field highlights_config table
---@field chars CharConfig
---@field show_guide_lines boolean
---@field show_inline_details boolean
---@field using_folds boolean Whether there are any symbols with visible children.

local DisplayContext = {}
DisplayContext.__index = DisplayContext

---@param symbols Symbols
---@return boolean
local function any_top_level_symbol_has_visible_children(symbols)
    for _, symbol in ipairs(symbols.root.children) do
        if symbols.states[symbol].visible_children > 0 then
            return true
        end
    end
    return false
end

---@param sidebar Sidebar
---@return DisplayContext
function DisplayContext:new(sidebar)
    local symbols = sidebar:current_symbols()
    local ft = nvim.buf_get_option(symbols.buf, "filetype")
    return setmetatable({
        symbols = symbols,
        ft = ft,
        kind_display_config = cfg.get_config_by_filetype(symbols.provider_config.kinds, ft),
        kind_default_config = symbols.provider_config.kinds.default,
        highlights_config = cfg.get_config_by_filetype(symbols.provider_config.highlights, ft),
        chars = sidebar.char_config,
        show_guide_lines = sidebar.show_guide_lines,
        show_inline_details = sidebar.show_inline_details,
        using_folds = any_top_level_symbol_has_visible_children(symbols),
    }, self)
end

---@class DisplayResult
---@field line_nr integer -- starting line number in a buffer, zero-indexed
---@field lines string[]
---@field highlights Highlight[]
---@field inline_details string[]

local DisplayResult = {}
DisplayResult.__index = DisplayResult

function DisplayResult:new()
    return setmetatable({
        line_nr = -1,
        lines = {},
        highlights = {},
        inline_details = {},
    }, self)
end

---@param symbol Symbol
---@return boolean
local function symbol_is_last_child(symbol)
    return symbol.parent ~= nil and symbol.parent.children[#symbol.parent.children] == symbol
end

---@param ctx DisplayContext
---@param symbol Symbol
---@param recurse boolean
---@return string[]
local function get_inline_details(ctx, symbol, recurse)
    if not ctx.show_inline_details then return {} end

    local result = {}
    local details_fun = (
        ctx.symbols.provider_config.details[ctx.ft]
        or function(symbol, _) return symbol.detail end
    )

    ---@param symbol Symbol
    local function rec(symbol)
        local state = ctx.symbols.states[symbol]
        if not state.visible then return end

        local details = details_fun(symbol, { symbol_states = ctx.symbols.states })
        table.insert(result, details)

        if recurse and not state.folded then
            for _, child in ipairs(symbol.children) do rec(child) end
        end
    end

    if symbol.level == 0 then
        for _,child in ipairs(symbol.children) do rec(child) end
    else
        rec(symbol)
    end

    return result
end

---@param ctx DisplayContext
---@param line_nr integer one-indexed
---@param symbol Symbol
---@param recurse boolean
---@return DisplayResult
local function get_display_lines(ctx, line_nr, symbol, recurse)
    local result = DisplayResult:new()
    result.line_nr = line_nr

    local line_tbl = {}
    local line_len = 0

    ---@param s string
    local function line_add(s)
        table.insert(line_tbl, s)
        line_len = line_len + #s
    end

    local function line_pop()
        line_len = line_len - #table.remove(line_tbl)
    end

    result.inline_details = get_inline_details(ctx, symbol, recurse)

    if symbol.level > 1 then
        line_add(ctx.using_folds and "  " or " ")
        if ctx.show_guide_lines then
            local temp_line = {}
            local curr = symbol.parent
            while curr ~= nil and curr.level > 1 do
                table.insert(temp_line, symbol_is_last_child(curr) and "  " or ctx.chars.guide_vert .. " ")
                curr = curr.parent
            end
            -- reverse the parts on insertion since we find them on the way up
            for i=#temp_line,1,-1 do line_add(temp_line[i]) end
        else
            for _=1,symbol.level-2 do line_add("  ") end
        end
    end

    ---@param symbol Symbol
    local function rec(symbol)
        local state = ctx.symbols.states[symbol]
        if not state.visible then return end
        local line_tbl_len_original = #line_tbl

        if state.visible_children > 0 then
            if ctx.show_guide_lines then
                local hl = nvim.Highlight:new({ group = ctx.chars.hl, line = line_nr + #result.lines, col_start = 1, col_end = line_len })
                table.insert(result.highlights, hl)
            end
            line_add(((state.folded and ctx.chars.folded) or ctx.chars.unfolded) .. " ")
        elseif ctx.show_guide_lines and symbol.level > 1 then
            line_add(
                ((symbol_is_last_child(symbol) and ctx.chars.guide_last_item) or ctx.chars.guide_middle_item) .. " "
            )
            local hl = nvim.Highlight:new({ group = ctx.chars.hl, line = line_nr + #result.lines, col_start = 1, col_end = line_len })
            table.insert(result.highlights, hl)
        else
            local space = (symbol.level == 1 and ctx.using_folds) and "  " or " "
            line_add(space)
        end

        local prefix_len = line_len

        local kind_display = cfg.kind_for_symbol(ctx.kind_display_config, symbol, ctx.kind_default_config)
        kind_display = (kind_display ~= "" and kind_display .. " ") or ""
        line_add(kind_display)
        line_add(symbol.name)

        local hl = nvim.Highlight:new({
            group = ctx.highlights_config[symbol.kind] or "",
            line = line_nr + #result.lines,
            col_start = prefix_len,
            col_end = prefix_len + #kind_display
        })
        table.insert(result.highlights, hl)

        local line = table.concat(line_tbl, "")
        table.insert(result.lines, line)

        while #line_tbl > line_tbl_len_original do
            line_pop()
        end

        if not recurse then return end
        if state.folded then return end

        if ctx.show_guide_lines and symbol.level > 1 then
             line_add(symbol_is_last_child(symbol) and "  " or ctx.chars.guide_vert .. " ")
        else
            line_add("  ")
        end
        for _, child in ipairs(symbol.children) do
            rec(child)
        end
        line_pop()
    end

    if symbol.level == 0 then
        for _,child in ipairs(symbol.children) do rec(child) end
    else
        rec(symbol)
    end

    return result
end

---@param buf integer
---@param start_line integer zero-indexed
---@param end_line integer zero-indexed
local function buf_clear_inline_details(buf, start_line, end_line)
    vim.api.nvim_buf_clear_namespace(buf, SIDEBAR_EXT_NS, start_line, end_line)
end

---@param buf integer
---@param start_line integer zero-indexed
---@param details string[]
local function buf_add_inline_details(buf, start_line, details)
    for line, detail in ipairs(details) do
        vim.api.nvim_buf_set_extmark(
            buf, SIDEBAR_EXT_NS, start_line + line - 1, -1,
            {
                virt_text = { { detail, "Comment" } },
                virt_text_pos = "eol",
                hl_mode = "combine",
            }
        )
    end
end

function Sidebar:refresh_view()
    local symbols = self:current_symbols()

    local ctx = DisplayContext:new(self)
    local result = get_display_lines(ctx, 1, symbols.root, true)

    vim.api.nvim_buf_clear_namespace(self.buf, SIDEBAR_EXT_NS, 0, -1)
    nvim.buf_set_content(self.buf, result.lines)
    buf_add_highlights(self.buf, result.highlights)
    buf_add_inline_details(self.buf, 0, result.inline_details)

    self:refresh_size()
end

function Sidebar:refresh_symbols()
    if not self:visible() then
        log.trace("Skipping")
        return
    else
        log.trace("Refreshing")
    end

    ---@return Symbol?
    local function _find_symbol_with_name(symbol, name)
        for _, sym in ipairs(symbol.children) do
            if sym.name == name then return sym end
        end
        return nil
    end

    ---@param old_symbols Symbols
    ---@param new_symbols Symbols
    local function preserve_folds(old_symbols, new_symbols)
        ---@param old Symbol
        ---@param new Symbol
        local function _preserve_folds(old, new)
            if old.level > 0 and old_symbols.states[old].folded then return end
            for _, new_sym in ipairs(new.children) do
                local old_sym = _find_symbol_with_name(old, new_sym.name)
                if old_sym ~= nil then
                    new_symbols.states[new_sym].folded = old_symbols.states[old_sym].folded
                    _preserve_folds(old_sym, new_sym)
                end
            end
        end

        _preserve_folds(old_symbols.root, new_symbols.root)
        new_symbols.states[new_symbols.root].folded = false
    end

    ---@param new_root Symbol
    ---@param provider string
    ---@param provider_config table
    local function _refresh_sidebar(new_root, provider, provider_config)
        local current_symbols = self:current_symbols()
        local new_symbols = Symbols_new()
        new_symbols.provider = provider
        new_symbols.provider_config = provider_config
        new_symbols.buf = self:source_win_buf()
        new_symbols.root = new_root
        new_symbols.states = SymbolStates_build(new_root)
        preserve_folds(current_symbols, new_symbols)
        local symbols_filter = (self.symbol_filters_enabled and self.symbol_filter)
            or function(_, _) return true end
        Symbols_apply_filter(new_symbols, symbols_filter)
        self:replace_current_symbols(new_symbols)
        self:refresh_view()
    end

    ---@param provider_name string
    local function on_fail(provider_name)
        local lines = { "", " [symbols.nvim]", "", " " .. provider_name .. " provider failed" }
        nvim.buf_set_content(self.buf, lines)
        self:refresh_size()
    end

    ---@param provider_name string
    local function on_timeout(provider_name)
        local lines = {
            "", " [symbols.nvim]", "", " " .. provider_name .. " provider timed out",
            "", " Try again or increase", " timeout in config."
        }
        nvim.buf_set_content(self.buf, lines)
        self:refresh_size()
    end

    local buf = self:source_win_buf()
    local ok = SymbolsRetriever_retrieve(
        self.symbols_retriever, buf, _refresh_sidebar, on_fail, on_timeout
    )
    if not ok then
        local ft = vim.bo[self:source_win_buf()].ft
        local lines
        if ft == "" then
            lines = { "", " [symbols.nvim]", "", " no filetype detected" }
        else
            lines = { "", " [symbols.nvim]", "", " no provider supporting", " " .. ft .. " found" }
        end
        nvim.buf_set_content(self.buf, lines)
        self:refresh_size()
    end
end

---@param symbols Symbols
---@param start_symbol Symbol
---@param value boolean
---@param depth_limit integer
---@return integer # number of changes
local function symbol_change_folded_rec(symbols, start_symbol, value, depth_limit)
    assert(depth_limit > 0)

    ---@param symbol Symbol
    ---@param dl integer
    ---@return integer #number of changes
    local function _change_folded_rec(symbol, dl)
        if dl <= 0 then return 0 end
        local state = symbols.states[symbol]
        local changes = (state.folded ~= value and #symbol.children > 0 and 1) or 0
        state.folded = value
        for _, child in ipairs(symbol.children) do
            if symbols.states[child].visible then
                changes = changes + _change_folded_rec(child, dl-1)
            end
        end
        return changes
    end

    return _change_folded_rec(start_symbol, depth_limit)
end

---@param symbols Symbols
---@param symbol Symbol
---@return integer
local function Symbol_count_lines(symbols, symbol)
    if not symbols.states[symbol].visible then return 0 end
    local lines = 1
    if not symbols.states[symbol].folded then
        for _, child in ipairs(symbol.children) do
            lines = lines + Symbol_count_lines(symbols, child)
        end
    end
    return lines
end

---@param target Symbol
---@param unfold boolean
function Sidebar:set_cursor_at_symbol(target, unfold)
    if target.level == 0 then
        nvim.win_set_cursor(self.win, 1, 0)
        return
    end

    ---@param outer_range Range
    ---@param inner_range Range
    ---@return boolean
    local function range_contains(outer_range, inner_range)
        return (
            (
                outer_range.start.line < inner_range.start.line
                or (
                    outer_range.start.line == inner_range.start.line
                    and outer_range.start.character <= inner_range.start.character
                )
            ) and (
                inner_range["end"].line < outer_range["end"].line
                or (
                    outer_range["end"].line == inner_range["end"].line
                    and inner_range["end"].character <= outer_range["end"].character
                )
            )
        )
    end

    local symbols = self:current_symbols()
    -- We need the top level ancestor to refresh the view efficiently.
    local top_level_ancestor = get_top_level_ancestor(target)
    local top_level_ancestor_lines = Symbol_count_lines(symbols, top_level_ancestor)
    local top_level_ancestor_line = -1
    local any_fold_changed = false
    local current_line = 0
    local current = symbols.root

    while current ~= target do
        local state = symbols.states[current]

        if not unfold and state.folded then
            -- we can't unfold or go deeper so current is the closest we can get to target
            break
        end

        if unfold and current.level > 0 and state.folded then
            state.folded = false
            any_fold_changed = true
        end

        local found = false
        for _, child in ipairs(current.children) do
            if range_contains(child.range, target.range) then
                if symbols.states[child].visible then
                    current_line = current_line + 1
                end
                current = child
                if current == top_level_ancestor then
                    top_level_ancestor_line = current_line
                end
                found = true
                break
            else
                current_line = current_line + Symbol_count_lines(symbols, child)
            end
        end

        if not found then
            -- target must be not visible so current is the closest we can get
            break
        end
    end

    if current_line == 0 then
        -- target must be not be visible and at the beginning of the list of symbols
        nvim.win_set_cursor(self.win, 1, 0)
        return
    end

    if top_level_ancestor_line == -1 then
        local symbol_path = vim.iter(Symbol_path(target)):join(".")
        log.warn("Top level ancestor not encountered when setting the cursor to: " .. symbol_path)
        return
    end

    if any_fold_changed then
        local ctx = DisplayContext:new(self)
        local result = get_display_lines(ctx, top_level_ancestor_line, top_level_ancestor, true)

        nvim.buf_set_modifiable(self.buf, true)
        nvim.buf_remove_lines(self.buf, top_level_ancestor_line-1, top_level_ancestor_lines)
        vim.api.nvim_buf_set_lines(self.buf, top_level_ancestor_line-1, top_level_ancestor_line-1, true, result.lines)
        nvim.buf_set_modifiable(self.buf, false)

        buf_add_highlights(self.buf, result.highlights)
        buf_add_inline_details(self.buf, top_level_ancestor_line-1, result.inline_details)
    end

    nvim.win_set_cursor(self.win, current_line, 0)
    self:schedule_refresh_size()
end

---@param win integer
---@param setting string
---@param value any
local function sidebar_show_toggle_notification(win, setting, value)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_option_value("bufhidden", "delete", { buf = buf })

    if type(value) == "boolean" then
        value = (value and "on") or "off"
    end

    local text =  " " .. setting .. ": " .. tostring(value)
    local lines = { text }
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

    local win_h = vim.api.nvim_win_get_height(win)
    local win_w = vim.api.nvim_win_get_width(win)
    local opts = {
        height = 1,
        width = win_w,
        border = "none",
        style = "minimal",
        relative = "win",
        win = win,
        anchor = "NW",
        row = win_h-2,
        col = 0,
    }
    local fw = vim.api.nvim_open_win(buf, false, opts)
    vim.defer_fn(
        function() vim.api.nvim_win_close(fw, true) end,
        1500
    )
end

function Sidebar:_goto_symbol()
    local symbol = self:current_symbol()
    vim.api.nvim_set_current_win(self.source_win)
    -- If we fail to jump to cursor then the file is no longer synchronized with the sidebar.
    local ok, err = pcall(
        vim.api.nvim_win_set_cursor,
        self.source_win,
        { symbol.range.start.line + 1, symbol.range.start.character }
    )
    if ok then
        vim.fn.win_execute(self.source_win, self.unfold_on_goto and "normal! zz zv" or "normal! zz")
        flash_highlight_under_cursor(self.source_win, 400, 1)
    else
        log.warn(err)
    end
end

function Sidebar:goto_symbol()
    self:_goto_symbol()
    if self.close_on_goto then self:close() end
end

function Sidebar:preview_open()
    self.preview:open()
end

function Sidebar:peek()
    local reopen_details = self.details.win ~= -1
    if reopen_details then self.details:close() end
    local reopen_preview = self.preview.win ~= -1
    if reopen_preview then self.preview:close() end
    self:_goto_symbol()
    vim.api.nvim_set_current_win(self.win)
    if reopen_details then self.details:open() end
    if reopen_preview then self:preview_open() end
end

function Sidebar:show_symbol_under_cursor()
    local symbols = self:current_symbols()
    local pos = Pos_from_point(vim.api.nvim_win_get_cursor(self.source_win))
    local symbol = symbol_at_pos(symbols.root, pos)
    self:set_cursor_at_symbol(symbol, true)
end

function Sidebar:toggle_show_details()
    if vim.api.nvim_win_is_valid(self.details.win) then
        self.details:close()
    else
        self.details:open()
    end
end

function Sidebar:goto_parent()
    local symbol, _ = self:current_symbol()
    local count = math.max(vim.v.count, 1)
    while count > 0 and symbol.level > 1 do
        symbol = symbol.parent
        assert(symbol ~= nil)
        count = count - 1
    end
    self:set_cursor_at_symbol(symbol, false)
end

---@param list Symbol[]
---@param symbol Symbol
---@return integer
local function find_symbol_in_list(list, symbol)
    local i = -1
    for child_i, child in ipairs(list) do
        i = child_i
        if child == symbol then break end
    end
    return i
end

function Sidebar:prev_symbol_at_level()
    local symbol, _ = self:current_symbol()
    local symbol_idx = find_symbol_in_list(symbol.parent.children, symbol)
    assert(symbol_idx ~= -1, "symbol not found")
    local count = math.max(vim.v.count, 1)
    local new_idx = math.max(symbol_idx - count, 1)
    self:set_cursor_at_symbol(symbol.parent.children[new_idx], false)
end

function Sidebar:next_symbol_at_level()
    local symbol, _ = self:current_symbol()
    local symbol_idx = find_symbol_in_list(symbol.parent.children, symbol)
    assert(symbol_idx ~= -1, "symbol not found")
    local count = math.max(vim.v.count, 1)
    local new_idx = math.min(symbol_idx + count, #symbol.parent.children)
    self:set_cursor_at_symbol(symbol.parent.children[new_idx], false)
end

---@param symbol Symbol
---@param symbol_line integer
function Sidebar:_unfold(symbol, symbol_line)
    local ctx = DisplayContext:new(self)
    local result = get_display_lines(ctx, symbol_line, symbol, true)

    nvim.buf_set_modifiable(self.buf, true)
    nvim.buf_remove_lines(self.buf, symbol_line-1, 1)
    vim.api.nvim_buf_set_lines(self.buf, symbol_line-1, symbol_line-1, true, result.lines)
    nvim.buf_set_modifiable(self.buf, false)

    buf_add_highlights(self.buf, result.highlights)
    buf_add_inline_details(self.buf, symbol_line-1, result.inline_details)

    self:set_cursor_at_symbol(symbol, false)
    self:schedule_refresh_size()
end

function Sidebar:unfold()
    local symbol, state = self:current_symbol()
    if not state.folded or state.visible_children == 0 then return end

    local cursor_line = vim.api.nvim_win_get_cursor(self.win)[1]
    state.folded = false

    self:_unfold(symbol, cursor_line)
end

---@param symbol Symbol
---@param symbol_line integer
---@param symbol_line_count integer
function Sidebar:_fold(symbol, symbol_line, symbol_line_count)
    local ctx = DisplayContext:new(self)
    local result = get_display_lines(ctx, symbol_line, symbol, false)
    assert(#result.lines == 1)

    buf_clear_inline_details(self.buf, symbol_line-1, symbol_line-1+symbol_line_count)
    nvim.buf_set_modifiable(self.buf, true)
    nvim.buf_remove_lines(self.buf, symbol_line-1, symbol_line_count)
    nvim.buf_set_lines(self.buf, symbol_line-1, result.lines)
    nvim.buf_set_modifiable(self.buf, false)

    buf_add_highlights(self.buf, result.highlights)
    buf_add_inline_details(self.buf, symbol_line-1, result.inline_details)

    self:set_cursor_at_symbol(symbol, false)
    self:schedule_refresh_size()
end

function Sidebar:fold()
    local symbol, state = self:current_symbol()

    if symbol.level == 0 then return end
    if symbol.level > 1 and (state.folded or #symbol.children == 0) then
        symbol = symbol.parent
        assert(symbol ~= nil)
        self:set_cursor_at_symbol(symbol, false)
        return
    end

    local symbols = self:current_symbols()
    local line_count = Symbol_count_lines(symbols, symbol)
    local cursor_line = vim.api.nvim_win_get_cursor(self.win)[1]
    state.folded = true
    self:_fold(symbol, cursor_line, line_count)
end

function Sidebar:unfold_recursively()
    local symbols = self:current_symbols()
    local symbol, _ = self:current_symbol()
    local symbol_lines = Symbol_count_lines(symbols, symbol)
    local changed = symbol_change_folded_rec(symbols, symbol, false, utils.MAX_INT)
    if changed == 0 then return end

    local cursor_line = vim.api.nvim_win_get_cursor(self.win)[1]
    local ctx = DisplayContext:new(self)
    local result = get_display_lines(ctx, cursor_line, symbol, true)

    nvim.buf_set_modifiable(self.buf, true)
    nvim.buf_remove_lines(self.buf, cursor_line-1, symbol_lines)
    vim.api.nvim_buf_set_lines(self.buf, cursor_line-1, cursor_line-1, true, result.lines)
    nvim.buf_set_modifiable(self.buf, false)

    buf_add_highlights(self.buf, result.highlights)
    buf_add_inline_details(self.buf, cursor_line-1, result.inline_details)

    self:set_cursor_at_symbol(symbol, false)
    self:schedule_refresh_size()
end

function Sidebar:fold_recursively()
    local symbols = self:current_symbols()
    local symbol = self:current_symbol()

    -- Line counts have to be calculated before changing folds. Otherwise, they would be synced
    -- to the internal symbols tree state instead of the displayed state in the buffer.
    local symbol_lines = Symbol_count_lines(symbols, symbol)

    local top_level_ancestor = get_top_level_ancestor(symbol)
    local top_level_ancestor_lines = Symbol_count_lines(symbols, top_level_ancestor)

    local changes = symbol_change_folded_rec(symbols, symbol, true, utils.MAX_INT)

    if changes == 0 then
        changes = symbol_change_folded_rec(symbols, top_level_ancestor, true, utils.MAX_INT)
        if changes == 0 then return end

        self:set_cursor_at_symbol(top_level_ancestor, false)
        local cursor_line = vim.api.nvim_win_get_cursor(self.win)[1]

        self:_fold(top_level_ancestor, cursor_line, top_level_ancestor_lines)
    else
        local cursor_line = vim.api.nvim_win_get_cursor(self.win)[1]
        self:_fold(symbol, cursor_line, symbol_lines)
    end
end

function Sidebar:unfold_one_level()
    local symbols = self:current_symbols()

    ---@param symbol Symbol
    ---@return integer
    local function find_level_to_unfold(symbol)
        if symbol.level ~= 0 and symbols.states[symbol].folded then
            return symbol.level
        end

        local min_level = utils.MAX_INT
        for _, sym in ipairs(symbol.children) do
            min_level = math.min(min_level, find_level_to_unfold(sym))
        end

        return min_level
    end

    local level = find_level_to_unfold(symbols.root)
    local count = math.max(vim.v.count, 1)
    local changes = symbol_change_folded_rec(symbols, symbols.root, false, level + count)
    if changes > 0 then self:refresh_view() end
end

function Sidebar:fold_one_level()
    local symbols = self:current_symbols()

    ---@param symbol Symbol
    ---@return integer
    local function find_level_to_fold(symbol)
        local max_level = (symbols.states[symbol].folded and 1) or symbol.level
        for _, sym in ipairs(symbol.children) do
            if #sym.children > 0 then
                max_level = math.max(max_level, find_level_to_fold(sym))
            end
        end
        return max_level
    end

    ---@param _symbols Symbols
    ---@param level integer
    ---@param value boolean
    local function _change_fold_at_level(_symbols, level, value)
        local function change_fold(symbol)
            local state = symbols.states[symbol]
            if symbol.level == level then state.folded = value end
            if symbol.level >= level then return end
            for _, sym in ipairs(symbol.children) do
                change_fold(sym)
            end
        end

        change_fold(_symbols.root)
    end

    local level = find_level_to_fold(symbols.root)
    local count = math.max(vim.v.count, 1)
    for i=1,math.min(level, count) do
        _change_fold_at_level(symbols, level - i + 1, true)
    end
    -- TODO: do not refresh if no changes made
    self:refresh_view()
end

function Sidebar:unfold_all()
    local symbols = self:current_symbols()
    local changes = symbol_change_folded_rec(symbols, symbols.root, false, utils.MAX_INT)
    if changes > 0 then self:refresh_view() end
end

function Sidebar:fold_all()
    local symbols = self:current_symbols()
    -- to make sure that we do not include the root in the number of changes
    symbols.states[symbols.root].folded = true
    local changes = symbol_change_folded_rec(symbols, symbols.root, true, utils.MAX_INT)
    symbols.states[symbols.root].folded = false
    if changes > 0 then self:refresh_view() end
end

function Sidebar:search()
    self:change_view("search")
end

function Sidebar:toggle_fold()
    local symbol, state = self:current_symbol()
    if #symbol.children == 0 then return end
    if state.folded then self:unfold() else self:fold() end
end

function Sidebar:toggle_details()
    self.show_inline_details = not self.show_inline_details
    if self.show_inline_details then
        local ctx = DisplayContext:new(self)
        local symbols = self:current_symbols()
        local details = get_inline_details(ctx, symbols.root, true)
        buf_add_inline_details(self.buf, 0, details)
    else
        buf_clear_inline_details(self.buf, 0, -1)
    end
    sidebar_show_toggle_notification(self.win, "inline details", self.show_inline_details)
end

function Sidebar:toggle_auto_details()
    self.details:toggle_auto_show()
    sidebar_show_toggle_notification(self.win, "auto details win", self.details.auto_show)
end

function Sidebar:toggle_auto_preview()
    self.preview:toggle_auto_show()
    sidebar_show_toggle_notification(self.win, "auto preview win", self.preview.auto_show)
end

function Sidebar:toggle_cursor_hiding()
    local cursor = self.gs.cursor
    if cursor.hide then
        reset_cursor(cursor)
    else
        activate_cursorline(cursor)
    end
    cursor.hide = not cursor.hide
    sidebar_show_toggle_notification(self.win, "cursor hiding", cursor.hide)
end

function Sidebar:toggle_cursor_follow()
    self.cursor_follow = not self.cursor_follow
    sidebar_show_toggle_notification(self.win, "cursor follow", self.cursor_follow)
end

function Sidebar:toggle_filters()
    self.symbol_filters_enabled = not self.symbol_filters_enabled
    self:refresh_symbols()
    sidebar_show_toggle_notification(self.win, "symbol filters", self.symbol_filters_enabled)
end

function Sidebar:toggle_auto_peek()
    self.auto_peek = not self.auto_peek
    sidebar_show_toggle_notification(self.win, "auto peek", self.auto_peek)
end

function Sidebar:toggle_close_on_goto()
    self.close_on_goto = not self.close_on_goto
    sidebar_show_toggle_notification(self.win, "close on goto", self.close_on_goto)
end

function Sidebar:toggle_auto_resize()
    self.auto_resize.enabled = not self.auto_resize.enabled
    if self.auto_resize.enabled then self:schedule_refresh_size() end
    sidebar_show_toggle_notification(self.win, "auto resize", self.auto_resize.enabled)
end

function Sidebar:decrease_max_width()
    local count = 5 * ((vim.v.count == 0 and 1) or vim.v.count)
    self.auto_resize.max_width = self.auto_resize.max_width - count
    if self.auto_resize.enabled then
        self:refresh_size()
    else
        vim.cmd("vert resize -" .. tostring(count))
    end
end

function Sidebar:increase_max_width()
    local count = 5 * ((vim.v.count == 0 and 1) or vim.v.count)
    self.auto_resize.max_width = self.auto_resize.max_width + count
    if self.auto_resize.enabled then
        self:refresh_size()
    else
        vim.cmd("vert resize +" .. tostring(count))
    end
end

---@type SidebarAction[]
local help_options_order = {
    "goto-symbol",
    "peek-symbol",
    "open-preview",
    "open-details-window",
    "show-symbol-under-cursor",
    "goto-parent",
    "prev-symbol-at-level",
    "next-symbol-at-level",
    "toggle-fold",
    "unfold",
    "fold",
    "unfold-recursively",
    "fold-recursively",
    "unfold-one-level",
    "fold-one-level",
    "unfold-all",
    "fold-all",
    "search",
    "toggle-inline-details",
    "toggle-auto-details-window",
    "toggle-auto-preview",
    "toggle-cursor-hiding",
    "toggle-cursor-follow",
    "toggle-filters",
    "toggle-auto-peek",
    "toggle-close-on-goto",
    "toggle-auto-resize",
    "decrease-max-width",
    "increase-max-width",
    "help",
    "close",
}
utils.assert_list_is_enum(help_options_order, cfg.SidebarAction, "help_options_order")

---@type table<integer, SidebarAction>
local action_order = {}
for num, action in ipairs(help_options_order) do
    action_order[action] = num
end

function Sidebar:help()
    local help_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_option_value("bufhidden", "delete", { buf = help_buf })
    vim.api.nvim_buf_set_option(help_buf, "filetype", M.FILE_TYPE_HELP)

    local keymaps = {}
    for i=1,#help_options_order do keymaps[i] = {} end

    for key, action in pairs(self.keymaps) do
        local ord = action_order[action]
        table.insert(keymaps[ord], key)
    end

    local keys_str = {}
    local max_key_len = 0
    for ord, keys in ipairs(keymaps) do
        keys_str[ord] = vim.iter(keys):join(" / ")
        max_key_len = math.max(max_key_len, #keys_str[ord])
    end

    local lines = {"", "Keymaps", ""}

    for num=1,#help_options_order do
        local padding = string.rep(" ", max_key_len - #keys_str[num] + 2)
        table.insert(lines, "  " .. keys_str[num] .. padding .. help_options_order[num])
    end

    local max_width = 0
    for line_no=1,#lines do
        lines[line_no] = " " .. lines[line_no]
        max_width = math.max(max_width, #lines[line_no])
    end

    nvim.buf_set_content(help_buf, lines)
    nvim.buf_set_modifiable(help_buf, false)

    local width = max_width + 1
    local height = #lines + 1

    local ui = vim.api.nvim_list_uis()[1]
    local row = math.floor((ui.height - height) / 2)
    local col = math.floor((ui.width - width) / 2)

    local opts = {
        title = "Symbols Help",
        relative = "editor",
        width = width,
        height = height,
        row = row,
        col = col,
        border = "single",
        style = "minimal",
    }
    local help_win = vim.api.nvim_open_win(help_buf, false, opts)
    nvim.win_set_option(help_win, "cursorline", true)
    vim.api.nvim_set_current_win(help_win)
    vim.api.nvim_win_set_cursor(help_win, { 2, 0 })

    vim.keymap.set(
        "n", "q",
        function() vim.api.nvim_win_close(help_win, true) end,
        { buffer = help_buf }
    )

    vim.api.nvim_create_autocmd(
        "BufLeave",
        {
            callback = function() vim.api.nvim_win_close(help_win, true) end,
            buffer = help_buf,
        }
    )
end

---@type table<SidebarAction, fun(sidebar: Sidebar)>
local sidebar_actions = {
    ["goto-symbol"] = Sidebar.goto_symbol,
    ["peek-symbol"] = Sidebar.peek,

    ["open-preview"] = Sidebar.preview_open,
    ["open-details-window"] = Sidebar.toggle_show_details,
    ["show-symbol-under-cursor"] = Sidebar.show_symbol_under_cursor,

    ["goto-parent"] = Sidebar.goto_parent,
    ["prev-symbol-at-level"] = Sidebar.prev_symbol_at_level,
    ["next-symbol-at-level"] = Sidebar.next_symbol_at_level,

    ["unfold"] = Sidebar.unfold,
    ["unfold-recursively"] = Sidebar.unfold_recursively,
    ["unfold-one-level"] = Sidebar.unfold_one_level,
    ["unfold-all"] = Sidebar.unfold_all,

    ["fold"] = Sidebar.fold,
    ["fold-recursively"] = Sidebar.fold_recursively,
    ["fold-one-level"] = Sidebar.fold_one_level,
    ["fold-all"] = Sidebar.fold_all,

    ["search"] = Sidebar.search,

    ["toggle-fold"] = Sidebar.toggle_fold,
    ["toggle-inline-details"] = Sidebar.toggle_details,
    ["toggle-auto-details-window"] = Sidebar.toggle_auto_details,
    ["toggle-auto-preview"] = Sidebar.toggle_auto_preview,
    ["toggle-cursor-hiding"] = Sidebar.toggle_cursor_hiding,
    ["toggle-cursor-follow"] = Sidebar.toggle_cursor_follow,
    ["toggle-filters"] = Sidebar.toggle_filters,
    ["toggle-auto-peek"] = Sidebar.toggle_auto_peek,
    ["toggle-close-on-goto"] = Sidebar.toggle_close_on_goto,
    ["toggle-auto-resize"] = Sidebar.toggle_auto_resize,
    ["decrease-max-width"] = Sidebar.decrease_max_width,
    ["increase-max-width"] = Sidebar.increase_max_width,

    ["help"] = Sidebar.help,
    ["close"] = Sidebar.close,
}

utils.assert_keys_are_enum(sidebar_actions, cfg.SidebarAction, "sidebar_actions")

function Sidebar:on_cursor_move()
    self.preview:on_cursor_move()
    self.details:on_cursor_move()
    if self.auto_peek then self:peek() end
end

function Sidebar:on_scroll()
    -- this function is used only with "symbols" view
    if self.details.win ~= -1 then
        self.details:close()
        self.details:open()
    end
    if self.preview.win ~= -1 then
        self.preview:close()
        self.preview:open()
    end
end

---@param sidebar Sidebar
---@param symbols_retriever SymbolsRetriever
---@param num integer
---@param config SidebarConfig
---@param gs GlobalState
---@param debug boolean
local function sidebar_new(sidebar, symbols_retriever, num, config, gs, debug)
    sidebar.deleted = false
    sidebar.source_win = vim.api.nvim_get_current_win()
    sidebar.symbols_retriever = symbols_retriever

    sidebar.num = num
    sidebar.gs = gs

    sidebar.preview_config = config.preview
    sidebar.preview.sidebar = sidebar
    sidebar.preview.auto_show = config.preview.show_always

    sidebar.details.sidebar = sidebar
    sidebar.details.show_debug_info = debug

    sidebar.search_view:init(sidebar)

    sidebar.show_inline_details = config.show_inline_details
    sidebar.details.auto_show = config.show_details_pop_up
    sidebar.show_guide_lines = config.show_guide_lines
    sidebar.char_config = config.chars
    sidebar.keymaps = config.keymaps
    sidebar.wrap = config.wrap
    sidebar.auto_resize = vim.deepcopy(config.auto_resize, true)
    sidebar.fixed_width = config.fixed_width
    sidebar.symbol_filters_enabled = true
    sidebar.symbol_filter = config.symbol_filter
    sidebar.cursor_follow = config.cursor_follow
    sidebar.auto_peek = config.auto_peek
    sidebar.close_on_goto = config.close_on_goto
    sidebar.unfold_on_goto = config.unfold_on_goto

    sidebar.buf = vim.api.nvim_create_buf(false, true)
    nvim.buf_set_modifiable(sidebar.buf, false)
    vim.api.nvim_buf_set_name(sidebar.buf, "symbols.nvim [" .. tostring(num) .. "]")
    vim.api.nvim_buf_set_option(sidebar.buf, "filetype", M.FILE_TYPE_MAIN)

    for key, action in pairs(config.keymaps) do
        vim.keymap.set(
            "n", key,
            function() sidebar_actions[action](sidebar) end,
            { buffer = sidebar.buf }
        )
    end

    vim.api.nvim_create_autocmd(
        { "CursorMoved" },
        {
            group = global_autocmd_group,
            buffer = sidebar.buf,
            callback = function() sidebar:on_cursor_move() end,
            nested = true,
        }
    )

    local cursor_follow = function()
        if (
            not sidebar.cursor_follow or
            not sidebar:visible() or
            sidebar.current_view ~= "symbols"
        ) then return end
        local win = vim.api.nvim_get_current_win()
        if win ~= sidebar.source_win then return end
        local symbols = sidebar:current_symbols()
        local pos = Pos_from_point(vim.api.nvim_win_get_cursor(sidebar.source_win))
        local symbol = symbol_at_pos(symbols.root, pos)
        sidebar:set_cursor_at_symbol(symbol, false)
    end

    vim.api.nvim_create_autocmd(
        { "CursorMoved" },
        {
            group = global_autocmd_group,
            callback = cursor_follow,
        }
    )

    vim.api.nvim_create_autocmd(
        { "WinScrolled" },
        {
            group = global_autocmd_group,
            buffer = sidebar.buf,
            callback = function() sidebar:on_scroll() end,
        }
    )

    vim.api.nvim_create_autocmd(
        { "WinEnter" },
        {
            group = global_autocmd_group,
            callback = function()
                sidebar.preview:on_win_enter()
                sidebar.details:on_win_enter()
                if vim.api.nvim_get_current_win() == sidebar.win and sidebar.gs.cursor.hide then
                    hide_cursor(sidebar)
                end
            end,
        }
    )
end

local function show_debug_in_current_window(sidebars)
    local buf = vim.api.nvim_create_buf(false, true)

    local lines = {}
    for _, sidebar in ipairs(sidebars) do
        local new_lines = vim.split(sidebar:to_string(), "\n") vim.list_extend(lines, new_lines) end

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)

    nvim.buf_set_modifiable(buf, false)
end

---@param sidebars Sidebar[]
---@param win integer
---@return Sidebar?
local function find_sidebar_for_win(sidebars, win)
    for _, sidebar in ipairs(sidebars) do
        if sidebar.source_win == win or sidebar.win == win then
            return sidebar
        end
    end
    return nil
end

---@param sidebars Sidebar[]
---@return Sidebar?, integer
local function find_sidebar_for_reuse(sidebars)
    for num, sidebar in ipairs(sidebars) do
        if sidebar.deleted then
            return sidebar, num
        end
    end
    return nil, -1
end


---@param gs GlobalState
---@param sidebars Sidebar[]
---@param config Config
local function setup_dev(gs, sidebars, config)
    log.LOG_LEVEL = config.dev.log_level

    ---@param pkg string
    local function unload_package(pkg)
        local esc_pkg = pkg:gsub("([^%w])", "%%%1")
        for module_name, _ in pairs(package.loaded) do
            if string.find(module_name, esc_pkg) then
                package.loaded[module_name] = nil
            end
        end
    end

    local function reload()
        remove_user_commands()
        if not pcall(function() vim.api.nvim_del_augroup_by_id(global_autocmd_group) end) then
            log.warn("Failed to remove autocmd group.")
        end

        for _, sidebar in ipairs(sidebars) do
            sidebar:destroy()
        end

        reset_cursor(gs.cursor)

        unload_package("symbols")
        require("symbols").setup(config)

        vim.cmd("SymbolsLogLevel " .. log.LOG_LEVEL_CMD_STRING[log.LOG_LEVEL])

        log.info("symbols.nvim reloaded")
    end

    local function debug()
        show_debug_in_current_window(sidebars)
    end

    local function show_config()
        local buf = vim.api.nvim_create_buf(false, true)
        local text = vim.inspect(config)
        local lines = vim.split(text, "\n")
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        local win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(win, buf)
        nvim.buf_set_modifiable(buf, false)
    end

    ---@type table<DevAction, fun()>
    local dev_action_to_fun = {
        ["reload"] = reload,
        ["debug"] = debug,
        ["show-config"] = show_config,
    }
    utils.assert_keys_are_enum(dev_action_to_fun, cfg.DevAction, "dev_action_to_fun")

    for key, action in pairs(config.dev.keymaps) do
        vim.keymap.set("n", key, dev_action_to_fun[action])
    end

end

---@param gs GlobalState
---@param sidebars Sidebar[]
---@param symbols_retriever SymbolsRetriever
---@param config Config
local function setup_user_commands(gs, sidebars, symbols_retriever, config)
    ---@return Sidebar
    local function _sidebar_new()
        local sidebar, num = find_sidebar_for_reuse(sidebars)
        if sidebar == nil then
            sidebar = Sidebar:new()
            table.insert(sidebars, sidebar)
            num = #sidebars
        end
        sidebar_new(sidebar, symbols_retriever, num, config.sidebar, gs, config.dev.enabled)
        return sidebar
    end

    create_user_command(
        "Symbols",
        function(e)
            local jump_to_sidebar = not e.bang

            local win = vim.api.nvim_get_current_win()
            for _, sidebar in ipairs(sidebars) do
                if not sidebar.deleted and sidebar.win == win then
                    vim.api.nvim_set_current_win(sidebar.source_win)
                    return
                end
            end

            local sidebar = find_sidebar_for_win(sidebars, win) or _sidebar_new()
            if sidebar:visible() then
                vim.api.nvim_set_current_win(sidebar.win)
                sidebar:refresh_symbols()
            else
                sidebar:open()
                sidebar:refresh_symbols()
                if jump_to_sidebar then vim.api.nvim_set_current_win(sidebar.win) end
            end
        end,
        {
            bang = true,
            desc = "Open the Symbols sidebar or jump to source code",
        }
    )

    create_user_command(
        "SymbolsOpen",
        function(e)
            local jump_to_sidebar = not e.bang
            local win = vim.api.nvim_get_current_win()
            local sidebar = find_sidebar_for_win(sidebars, win) or _sidebar_new()
            if not sidebar:visible() then
                sidebar:open()
                sidebar:refresh_symbols()
                if jump_to_sidebar then vim.api.nvim_set_current_win(sidebar.win) end
            end
        end,
        {
            bang = true,
            desc = "Opens the Symbols sidebar"
        }
    )

    create_user_command(
        "SymbolsClose",
        function()
            local win = vim.api.nvim_get_current_win()
            local sidebar = find_sidebar_for_win(sidebars, win)
            if sidebar ~= nil then
                sidebar:close()
            end
        end,
        { desc = "Close the Symbols sidebar" }
    )

    create_user_command(
        "SymbolsToggle",
        function(e)
            local jump_to_sidebar = not e.bang
            local win = vim.api.nvim_get_current_win()
            local sidebar = find_sidebar_for_win(sidebars, win) or _sidebar_new()
            if sidebar:visible() then
                sidebar:close()
            else
                sidebar:open()
                sidebar:refresh_symbols()
                if jump_to_sidebar then vim.api.nvim_set_current_win(sidebar.win) end
            end
        end,
        {
            bang = true,
            desc = "Open or close the Symbols sidebar"
        }
    )

    create_user_command(
        "SymbolsDebugToggle",
        function()
            config.dev.enabled = not config.dev.enabled
            for _, sidebar in ipairs(sidebars) do
                sidebar.details.show_debug_info = config.dev.enabled
            end
            LOG_LEVEL = (config.dev.enabled and config.dev.log_level) or log.DEFAULT_LOG_LEVEL
        end,
        {}
    )

    log.create_change_log_level_user_command(
        "SymbolsLogLevel",
        "Change the Symbols debug level",
        create_user_command
    )
end

---@param gs GlobalState
---@param sidebars Sidebar[]
---@param symbols_retriever SymbolsRetriever
local function setup_autocommands(gs, sidebars, symbols_retriever)
    vim.api.nvim_create_autocmd(
        { "WinEnter" },
        {
            group = global_autocmd_group,
            callback = function()
                if gs.cursor.hide then
                    local win = vim.api.nvim_get_current_win()
                    for _, sidebar in ipairs(sidebars) do
                        if sidebar.win == win then
                            activate_cursorline(gs.cursor)
                            return
                        end
                    end
                end
            end
        }
    )

    vim.api.nvim_create_autocmd(
        { "WinLeave" },
        {
            group = global_autocmd_group,
            callback = function()
                if gs.cursor.hide or gs.cursor.hidden then
                    reset_cursor(gs.cursor)
                end
            end
        }
    )

    vim.api.nvim_create_autocmd(
        { "WinClosed" },
        {
            group = global_autocmd_group,
            callback = function(t)
                local win = tonumber(t.match, 10)
                local tab_wins = #vim.api.nvim_tabpage_list_wins(0)
                for _, sidebar in ipairs(sidebars) do
                    if tab_wins > 2 and sidebar.source_win == win then
                        sidebar:destroy()
                    end
                    if sidebar.win == win then
                        sidebar:close()
                    end
                end
            end
        }
    )

    vim.api.nvim_create_autocmd(
        { "BufWritePost", "FileChangedShellPost" },
        {
            group = global_autocmd_group,
            callback = function(t)
                local source_buf = t.buf
                symbols_retriever.cache[source_buf].fresh = false
            end
        }
    )

    vim.api.nvim_create_autocmd(
        { "LspAttach", "BufWinEnter", "BufWritePost", "FileChangedShellPost" },
        {
            group = global_autocmd_group,
            callback = function(t)
                local source_buf = t.buf
                for _, sidebar in ipairs(sidebars) do
                    if sidebar:source_win_buf() == source_buf then
                        sidebar:refresh_symbols()
                    end
                end
            end
        }
    )

    local function try_to_restore_win()
        local win = vim.api.nvim_get_current_win()
        local buf = vim.api.nvim_get_current_buf()
        for _, sidebar in ipairs(sidebars) do
            if (
                sidebar.win == win
                and sidebar.buf ~= buf
                and sidebar.search_view.buf ~= buf
            ) then
                sidebar:win_restore()
                return
            end
        end
    end

    local function close_last_win()
        if #vim.api.nvim_tabpage_list_wins(0) > 1 then return end
        local buf = vim.api.nvim_get_current_buf()
        for _, sidebar in ipairs(sidebars) do
            if sidebar.buf == buf or sidebar.search_view.buf == buf then
                vim.cmd("q")
                sidebar:destroy()
            end
        end
    end

    vim.api.nvim_create_autocmd(
        { "BufEnter" },
        {
            group = global_autocmd_group,
            callback = function()
                try_to_restore_win()
                close_last_win()
            end
        }
    )

    vim.api.nvim_create_autocmd(
        { "WinScrolled" },
        {
            group = global_autocmd_group,
            callback = function(e)
                local win = tonumber(e.match)
                assert(win ~= nil)
                local sidebar = find_sidebar_for_win(sidebars, win)
                if sidebar == nil then return end
                sidebar:schedule_refresh_size()
            end
        }
    )
end

---@type Sidebar[]
local sidebars = {}

function M.setup(...)
    local config = cfg.prepare_config(...)

    ---@type GlobalState
    local gs = GlobalState_new()
    gs.cursor.hide = config.sidebar.hide_cursor
    gs.settings.open_direction = config.sidebar.open_direction
    gs.settings.on_open_make_windows_equal = config.sidebar.on_open_make_windows_equal

    ---@type [string, Provider][]
    local providers = {
        { "lsp", providers.LspProvider },
        { "treesitter", providers.TSProvider },
    }
    local symbols_retriever = SymbolsRetriever_new(providers, config.providers)

    if config.dev.enabled then setup_dev(gs, sidebars, config) end
    setup_user_commands(gs, sidebars, symbols_retriever, config)
    setup_autocommands(gs, sidebars, symbols_retriever)
end

local apisupport_getsidebar = function()
    local win = vim.api.nvim_get_current_win()
    local sidebar = find_sidebar_for_win(sidebars, win)
    return sidebar
end

M.api = {
    action = function(act)
        vim.validate({ act = { act, "string" } })
        local sidebar = apisupport_getsidebar()
        if sidebar ~= nil and sidebar_actions[act] ~= nil then
            sidebar_actions[act](sidebar)
        end
    end,
    refresh_symbols = function()
        local sidebar = apisupport_getsidebar()
        if sidebar ~= nil then
            sidebar:refresh_symbols()
        end
    end
}

return M
