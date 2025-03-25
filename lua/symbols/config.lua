local M = {}

---@class CharConfig
---@field folded string
---@field unfolded string
---@field guide_vert string
---@field guide_middle_item string
---@field guide_last_item string
---@field hl_guides string
---@field hl_foldmarker string

---@enum SidebarAction
M.SidebarAction = {
    GotoSymbol = "goto-symbol",
    PeekSymbol = "peek-symbol",
    OpenPreview = "open-preview",
    GotoParent = "goto-parent",
    NextSymbolAtLevel = "next-symbol-at-level",
    PrevSymbolAtLevel = "prev-symbol-at-level",
    ShowSymbolUnderCursor = "show-symbol-under-cursor",
    OpenDetailsWindow = "open-details-window",
    ToggleFold = "toggle-fold",
    Unfold = "unfold",
    UnfoldRecursively = "unfold-recursively",
    UnfoldOneLevel = "unfold-one-level",
    UnfoldAll = "unfold-all",
    Fold = "fold",
    FoldRecursively = "fold-recursively",
    FoldOneLevel = "fold-one-level",
    FoldAll = "fold-all",
    Search = "search",
    ToggleInlineDetails = "toggle-inline-details",
    ToggleAutoDetailsWindow = "toggle-auto-details-window",
    ToggleAutoPreview = "toggle-auto-preview",
    ToggleCursorHiding = "toggle-cursor-hiding",
    ToggleCursorFollow = "toggle-cursor-follow",
    ToggleFilters = "toggle-filters",
    ToggleAutoResize = "toggle-auto-resize",
    ToggleAutoPeek = "toggle-auto-peek",
    ToggleCloseOnGoto = "toggle-close-on-goto",
    DecreaseMaxWidth = "decrease-max-width",
    IncreaseMaxWidth = "increase-max-width",
    Help = "help",
    Close = "close",
}

---@alias KeymapsConfig table<string, SidebarAction?>

---@enum DevAction
M.DevAction = {
    Reload = "reload",
    Debug = "debug",
    ShowConfig = "show-config",
}

---@enum PreviewAction
M.PreviewAction = {
    Close = "close",
    GotoCode = "goto-code",
}

---@class PreviewConfig
---@field show_always boolean
---@field show_line_number boolean
---@field auto_size boolean
---@field auto_size_extra_lines integer
---@field fixed_size_height integer
---@field min_window_height integer
---@field max_window_height integer
---@field window_width integer
---@field keymaps table<string, PreviewAction>

---@class DevConfig
---@field enabled boolean
---@field log_level integer
---@field keymaps table<string, DevAction>

---@class AutoResizeConfig
---@field enabled boolean
---@field min_width integer
---@field max_width integer

---@enum OpenDirection
M.OpenDirection = {
    Left = "left",
    Right = "right",
    TryLeft = "try-left",
    TryRight = "try-right",
}

---@class SidebarConfig
---@field hide_cursor boolean
---@field open_direction OpenDirection
---@field on_open_make_windows_equal boolean
---@field cursor_follow boolean
---@field auto_resize AutoResizeConfig
---@field fixed_width integer
---@field symbol_filter fun(ft: string, symbol: Symbol): boolean
---@field show_inline_details boolean
---@field show_details_pop_up boolean
---@field show_guide_lines boolean
---@field auto_peek boolean
---@field close_on_goto boolean
---@field unfold_on_goto boolean
---@field wrap boolean
---@field chars CharConfig
---@field preview PreviewConfig
---@field keymaps KeymapsConfig
---@field hl_details string

---@class SymbolDisplayConfig
---@field kind string?
---@field highlight string

---@class LspFileTypeConfig
---@field symbol_display table<string, SymbolDisplayConfig>

---@alias ProviderKindFun fun(symbol: Symbol): string

---@class ProviderDetailsFunCtx
---@field symbol_states SymbolStates

---@alias ProviderDetailsFun fun(symbol: Symbol, ctx: ProviderDetailsFunCtx): string

---@class ProviderConfig
---@field details table<string, ProviderDetailsFun>
---@field kinds table<string, table<string, string> | ProviderKindFun>
---@field highlights table<string, table<string, string>>

---@class LspConfig : ProviderConfig
---@field timeout_ms integer

---@class TreesitterConfig : ProviderConfig

---@class ProvidersConfig
---@field lsp LspConfig
---@field treesitter TreesitterConfig

---@class Config
---@field sidebar SidebarConfig
---@field providers ProvidersConfig
---@field dev DevConfig

---@type Config
M.default = {
    sidebar = {
        hide_cursor = true,
        open_direction = "try-left",
        on_open_make_windows_equal = true,
        cursor_follow = true,
        auto_resize = {
            enabled = true,
            min_width = 20,
            max_width = 40,
        },
        fixed_width = 30,
        symbol_filter = function(_, _) return true end,
        show_inline_details = false,
        show_details_pop_up = false,
        show_guide_lines = true,
        auto_peek = false,
        close_on_goto = false,
        wrap = false,
        unfold_on_goto = false,
        hl_details = "Comment",
        chars = {
            folded = "",
            unfolded = "",
            guide_vert = "│",
            guide_middle_item = "├",
            guide_last_item = "└",
            hl_guides = "Comment",
            hl_foldmarker = "Operator"
        },
        preview = {
            show_always = false,
            show_line_number = false,
            auto_size = true,
            auto_size_extra_lines = 6,
            fixed_size_height = 12,
            min_window_height = 7,
            max_window_height = 30,
            window_width = 100,
            keymaps = {
                ["q"] = "close",
            },
        },
        keymaps = {
            ["<CR>"] = "goto-symbol",
            ["<RightMouse>"] = "peek-symbol",
            ["o"] = "peek-symbol",

            ["K"] = "open-preview",
            ["d"] = "open-details-window",
            ["gs"] = "show-symbol-under-cursor",

            ["gp"] = "goto-parent",
            ["[["] = "prev-symbol-at-level",
            ["]]"] = "next-symbol-at-level",

            ["l"] = "unfold",
            ["zo"] = "unfold",
            ["L"] = "unfold-recursively",
            ["zO"] = "unfold-recursively",
            ["zr"] = "unfold-one-level",
            ["zR"] = "unfold-all",

            ["h"] = "fold",
            ["zc"] = "fold",
            ["H"] = "fold-recursively",
            ["zC"] = "fold-recursively",
            ["zm"] = "fold-one-level",
            ["zM"] = "fold-all",

            ["s"] = "search",

            ["td"] = "toggle-inline-details",
            ["tD"] = "toggle-auto-details-window",
            ["tp"] = "toggle-auto-preview",
            ["tch"] = "toggle-cursor-hiding",
            ["tcf"] = "toggle-cursor-follow",
            ["tf"] = "toggle-filters",
            ["to"] = "toggle-auto-peek",
            ["tg"] = "toggle-close-on-goto",
            ["t="] = "toggle-auto-resize",
            ["t["] = "decrease-max-width",
            ["t]"] = "increase-max-width",

            ["<2-LeftMouse>"] = "toggle-fold",

            ["q"] = "close",
            ["?"] = "help",
            ["g?"] = "help",
        },
    },
    providers = {
        lsp = {
            timeout_ms = 2000,
            details = {},
            kinds = { default = {} },
            highlights = {
                default = {
                    File = "Identifier",
                    Module = "Include",
                    Namespace = "Include",
                    Package = "Include",
                    Class = "Type",
                    Method = "Function",
                    Property = "Identifier",
                    Field = "Identifier",
                    Constructor = "Special",
                    Enum = "Type",
                    Interface = "Type",
                    Function = "Function",
                    Variable = "Constant",
                    Constant = "Constant",
                    String = "String",
                    Number = "Number",
                    Boolean = "Boolean",
                    Array = "Constant",
                    Object = "Type",
                    Key = "Type",
                    Null = "Type",
                    EnumMember = "Identifier",
                    Struct = "Structure",
                    Event = "Type",
                    Operator = "Identifier",
                    TypeParameter = "Identifier",
                }
            },
        },
        treesitter = {
            details = {},
            kinds = { default = {} },
            highlights = {
                markdown = {
                    H1 = "@markup.heading.1.markdown",
                    H2 = "@markup.heading.2.markdown",
                    H3 = "@markup.heading.3.markdown",
                    H4 = "@markup.heading.4.markdown",
                    H5 = "@markup.heading.5.markdown",
                    H6 = "@markup.heading.6.markdown",
                },
                help = {
                    H1 = "@markup.heading.1.vimdoc",
                    H2 = "@markup.heading.2.vimdoc",
                    H3 = "@markup.heading.3.vimdoc",
                    Tag = "@label.vimdoc",
                },
                json = {
                    Object = "Type",
                    Array = "Constant",
                    String = "String",
                    Number = "Number",
                    Boolean = "Boolean",
                    Null = "Type",
                },
                jsonl = {
                    Object = "Type",
                    Array = "Constant",
                    String = "String",
                    Number = "Number",
                    Boolean = "Boolean",
                    Null = "Type",
                },
                org = {
                    H1 = "@markup.heading.1.markdown",
                    H2 = "@markup.heading.2.markdown",
                    H3 = "@markup.heading.3.markdown",
                    H4 = "@markup.heading.4.markdown",
                    H5 = "@markup.heading.5.markdown",
                    H6 = "@markup.heading.6.markdown",
                    H7 = "@markup.heading.6.markdown",
                    H8 = "@markup.heading.6.markdown",
                    H9 = "@markup.heading.6.markdown",
                    H10 = "@markup.heading.6.markdown",
                },
                make = {
                    Target = "",
                },
                default = {},
            }
        },
    },
    dev = {
        enabled = false,
        log_level = vim.log.levels.ERROR,
        keymaps = {},
    }
}

---@param ... table
---@return Config
function M.prepare_config(...)
    local function extend_from_default(cfg)
        for ft, _ in pairs(cfg) do
            if ft ~= "default" then
                cfg[ft] = vim.tbl_deep_extend("force", cfg.default, cfg[ft])
            end
        end
    end

    local config = M.default
    if #{...} > 0 then
        config = vim.tbl_deep_extend("force", M.default, ...)
    end

    local providers = { "lsp", "treesitter" }
    for _, provider in ipairs(providers) do
        extend_from_default(config.providers[provider].highlights)
    end

    return config
end

---@param config table
---@param filetype string
---@return table
function M.get_config_by_filetype(config, filetype)
    local ft_config = config[filetype]
    if ft_config ~= nil then return ft_config end
    return config.default
end

---@param kinds table<string, string> | ProviderKindFun
---@param symbol Symbol
---@param default_config (table<string, string> | ProviderKindFun) | nil
---@return string
function M.kind_for_symbol(kinds, symbol, default_config)
    local kind = nil
    if type(kinds) == "function" then
        kind = kinds(symbol)
    else
        kind = kinds[symbol.kind]
    end
    if kind ~= nil then return kind end
    if default_config ~= nil and default_config[symbol.kind] ~= nil then
        return default_config[symbol.kind]
    end
    if symbol.kind ~= nil then return symbol.kind end
    -- We shouldn't ever get here, but somehow we do: https://github.com/oskarrrrrrr/symbols.nvim/issues/11
    return ""
end

return M
