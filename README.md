<!-- panvimdoc-ignore-start -->

# symbols.nvim

Sidebar with a list of symbols. Gives an overview of a file and allows quick
navigation.

> **Warning**
>
> `symbols.nvim` is in beta. You may encounter bugs and breaking changes.
> For a more stable experience use tags (e.g. "v0.1.0") with you plugin manager.

https://github.com/user-attachments/assets/6262fa59-a320-4043-a3ba-97617f0fd8b3

## Features

- **Listing Symbols** - duh. Uses LSP servers and Treesitter parsers which have to
  be configured by the user.
- **Fuzzy Search** - fuzzy search symbols directly from the sidebar
- **Preview Window** - glance at the code before committing to your next action.
  You can also edit the file in the preview window.
- **Inline Details** - symbol details can be displayed inline. Those details are
  given by a provider (e.g. LSP).
- **Dynamic Settings** - some of the settings can be changed on the fly, without
  changing the config and reopening Neovim.
- **Preserving Folds** - the sidebar preserves folds on changes (at least most of
  them, most of the time).
- **Independent Sidebars** - each sidebar has it's own view (folds) and settings,
  even when there are multiple sidebars showing symbols for the same file.
- **Custom Display Rules** - symbols formatting and filtering can be configured per
  language. The goal is to provide great default configurations for many
  languages while allowing the user to make adjusments according to their
  preference.
- **Mouse Support** - you can use your mouse, no judgement.

<!-- panvimdoc-ignore-end -->

# Requirements

- Neovim 0.10+
- LSP servers for desired languages
- Treesitter parsers (see [Supported Languages](#supported-languages))

# Quick Start

Using lazy.nvim:

```lua
{
    "oskarrrrrrr/symbols.nvim",
    config = function()
        local r = require("symbols.recipes")
        require("symbols").setup(r.DefaultFilters, r.AsciiSymbols, {
            -- custom settings here
            -- e.g. hide_cursor = false
        })
        vim.keymap.set("n", ",s", "<cmd> Symbols<CR>")
        vim.keymap.set("n", ",S", "<cmd> SymbolsClose<CR>")
    end
}
```

# Supported Languages

There are two sources of symbols that are displayed in the sidebar:
1. LSP servers configured by the user (for example with [mason.nvim](https://github.com/williamboman/mason.nvim))
2. Treesitter parsers installed by the user (for example with `TSInstall` command)

Virtually any LSP server should work with the sidebar.

Languages supported through treesitter (Treesitter parser name in brackets):
- Markdown (markdown)
- Vimdoc (vimdoc)
- Org (org)
- JSON (json)
- JSON Lines (json)
- Makefile (make)

When a language is supported by both sources, the LSP servers take precedence
over Treesitter.

# Tips

## Help

Press `?` in the sidebar to see the available keymaps or run `:help symbols`.

## Fuzzy Search

Press `s` to start a fuzzy search. Use `<S-Tab>` and `<Tab>` to go up and down
the search results list without leaving the prompt window or navigate the search
history with `<C-j>` and `<C-k>`. Go to symbol with `<Cr>` or press `<Esc>` to
focus the search results window and peek symbols with `o`. Press `<Esc>` again
to go back to the symbols list or press `q` to close the sidebar.

## Preview Window

Press the preview window keymap (by default "K") once to open it, the second
time to jump to it. You can now move around the buffer and make changes. Press
"q" to close the window or jump to the sidebar if auto preview is on. Yes, this
means that by default you can't record macros in the preview window.

## Keymaps

How to remove a default keymap? Just set the value to `nil`.

## Dynamic Settings

A lot of settings can be changed on the fly by using keymaps starting with "t".
For example, try out "td" to toggle inline details, "t=" to toggle sidebar auto
resizing or "tp" to toggle auto preview.

## Inline Details

By pressing "td" you can show inline details which are provided by some LSP
servers. They give useful information about certain symbols. For instance, for
a function the details might be the function params, for a variable it might be
the initial value.
Examples of languages that have nice support for details are Lua, Go and Rust.
On the flip side, Javascript and Python do not show any details.

## Navigation

Sometimes you want to get to a deeply nested symbol and unfold all the symbols
on the way. To do that for the symbol under the cursor in the source window
press "gs" when in the sidebar. Other useful mappings for more advanced
navigation are:

- "\[\[" and "\]\]" to go to the previous and next symbol on the same
  level. Can be used with a count.
- "gp" to go to parent symbol, can be used with a count.
- "L"/"zO" and "H"/"zC" for recursively opening and closing folds under the
  cursor . Useful for changing only part of the tree, whereas "zr", "zR", "zm"
  and "zM" affect the whole tree.

You can navigate the sidebar with a mouse. Left click to select a symbol,
double click to toggle fold, right click to peek the symbol.

# Commands

- `:Symbols[!]` A command designed to be used as your main mapping. Opens the
  Symbols sidebar and jumps to it unless called with the bang (`!`). If called
  when the sidebar is already open then jumps to it regardless of the bang.
  When called in a sidebar jumps back to the source code.
- `:SymbolsToggle[!]` An alternative main mapping. Opens the sidebar and jumps
  to it unless called with the bang (`!`). Closes the sidebar if already open.
- `:SymbolsOpen[!]` Opens the sidebar and jumps to it unless called with the
  bang (`!`).
- `:SymbolsClose` Closes the sidebar.

# Configuration

To use the plugin you must run the setup function: `require("symbols").setup()`.
Setup function takes any number of config arguments which will be merged with
the default config.

There are a few predefined recipes (configs) that you can use:

- DefaultFilters - filters out excessive symbols. For example, the Lua LSP
  server provides a symbol for each `if`, `elseif`, `else` and `for` and they
  are discarded by this config.
- AsciiSymbols - symbol kind displayed as text. For instance, "Function" kind 
  might be displayed as "fun", "fn", "func" or "def" depending on the language.
- FancySymbols - symbol kind will be displated as an icon. Needs `lspkind.nvim`.

The recipes are available in `symbols.recipes` module.

## Reference

Default config below.

```lua
{
    sidebar = {
        -- Hide the cursor when in sidebar.
        hide_cursor = true,
        -- Side on which the sidebar will open, available options:
        -- try-left  Opens to the left of the current window if there are no
        --           windows there. Otherwise opens to the right.
        -- try-right Opens to the right of the current window if there are no
        --           windows there. Otherwise opens to the left.
        -- right     Always opens to the right of the current window.
        -- left      Always opens to the left of the current window.
        open_direction = "try-left",
        -- Whether to run `wincmd =` after opening a sidebar.
        on_open_make_windows_equal = true,
        -- Whether the cursor in the sidebar should automatically follow the
        -- cursor in the source window. Does not unfold the symbols. You can jump
        -- to symbol with unfolding with "gs" by default.
        cursor_follow = true,
        auto_resize = {
            -- When enabled the sidebar will be resized whenever the view changes.
            -- For example, after folding/unfolding symbols, after toggling inline details
            -- or whenever the source file is saved.
            enabled = true,
            -- The sidebar will never be auto resized to a smaller width then `min_width`.
            min_width = 20,
            -- The sidebar will never be auto resized to a larger width then `max_width`.
            max_width = 40,
        },
        -- Default sidebar width.
        fixed_width = 30,
        -- Allows to filter symbols. By default all the symbols are shown.
        symbol_filter = function(filetype, symbol) return true end,
        -- Show inline details by default.
        show_inline_details = false,
        -- Show details floating window at all times.
        show_details_pop_up = false,
        -- When enabled every symbol will be automatically peeked after cursor
        -- movement.
        auto_peek = false,
        -- Whether the sidebar should unfold the target buffer on goto
        -- This simply sends a zv after the zz
        unfold_on_goto = false,
        -- Whether to close the sidebar on goto symbol.
        close_on_goto = false,
        -- Whether the sidebar should wrap text.
        wrap = false,
        -- Whether to show the guide lines.
        show_guide_lines = true,
        chars = {
            folded = "",
            unfolded = "",
            guide_vert = "│",
            guide_middle_item = "├",
            guide_last_item = "└",
            -- use this highlight group for the guide lines
            hl = "Comment"
        },
        -- Config for the preview window.
        preview = {
            -- Whether the preview window is always opened when the sidebar is
            -- focused.
            show_always = false,
            -- Whether the preview window should show line numbers.
            show_line_number = false,
            -- Whether to determine the preview window's height automatically.
            auto_size = true,
            -- The total number of extra lines shown in the preview window.
            auto_size_extra_lines = 6,
            -- Minimum window height when `auto_size` is true.
            min_window_height = 7,
            -- Maximum window height when `auto_size` is true.
            max_window_height = 30,
            -- Preview window size when `auto_size` is false.
            fixed_size_height = 12,
            -- Desired preview window width. Actuall width will be capped at
            -- the current width of the source window width.
            window_width = 100,
            -- Keymaps for actions in the preview window. Available actions:
            -- close: Closes the preview window.
            -- goto-code: Changes window to the source code and moves cursor to
            --            the same position as in the preview window.
            -- Note: goto-code is not set by default because the most natual
            -- key would be Enter but some people already have that key mapped.
            keymaps = {
                ["q"] = "close",
            },
        },
        -- Keymaps for actions in the sidebar. All available actions are used
        -- in the default keymaps.
        keymaps = {
            -- Jumps to symbol in the source window.
            ["<CR>"] = "goto-symbol",
            -- Jumps to symbol in the source window but the cursor stays in the
            -- sidebar.
            ["<RightMouse>"] = "peek-symbol",
            ["o"] = "peek-symbol",

            -- Opens a floating window with symbol preview.
            ["K"] = "open-preview",
            -- Opens a floating window with symbol details.
            ["d"] = "open-details-window",

            -- In the sidebar jumps to symbol under the cursor in the source
            -- window. Unfolds all the symbols on the way.
            ["gs"] = "show-symbol-under-cursor",
            -- Jumps to parent symbol. Can be used with a count, e.g. "3gp"
            -- will go 3 levels up.
            ["gp"] = "goto-parent",
            -- Jumps to the previous symbol at the same nesting level.
            ["[["] = "prev-symbol-at-level",
            -- Jumps to the next symbol at the same nesting level.
            ["]]"] = "next-symbol-at-level",

            -- Unfolds the symbol under the cursor.
            ["l"] = "unfold",
            ["zo"] = "unfold",
            -- Unfolds the symbol under the cursor and all its descendants.
            ["L"] = "unfold-recursively",
            ["zO"] = "unfold-recursively",
            -- Reduces folding by one level. Can be used with a count,
            -- e.g. "3zr" will unfold 3 levels.
            ["zr"] = "unfold-one-level",
            -- Unfolds all symbols in the sidebar.
            ["zR"] = "unfold-all",

            -- Folds the symbol under the cursor.
            ["h"] = "fold",
            ["zc"] = "fold",
            -- Folds the symbol under the cursor and all its descendants.
            ["H"] = "fold-recursively",
            ["zC"] = "fold-recursively",
            -- Increases folding by one level. Can be used with a count,
            -- e.g. "3zm" will fold 3 levels.
            ["zm"] = "fold-one-level",
            -- Folds all symbols in the sidebar.
            ["zM"] = "fold-all",

            -- Start fuzzy search.
            ["s"] = "search",

            -- Toggles inline details (see sidebar.show_inline_details).
            ["td"] = "toggle-inline-details",
            -- Toggles auto details floating window (see sidebar.show_details_pop_up).
            ["tD"] = "toggle-auto-details-window",
            -- Toggles auto preview floating window.
            ["tp"] = "toggle-auto-preview",
            -- Toggles cursor hiding (see sidebar.auto_resize.
            ["tch"] = "toggle-cursor-hiding",
            -- Toggles cursor following (see sidebar.cursor_follow).
            ["tcf"] = "toggle-cursor-follow",
            -- Toggles symbol filters allowing the user to see all the symbols
            -- given by the provider.
            ["tf"] = "toggle-filters",
            -- Toggles automatic peeking on cursor movement (see sidebar.auto_peek).
            ["to"] = "toggle-auto-peek",
            -- Toggles closing on goto symbol (see sidebar.close_on_goto).
            ["tg"] = "toggle-close-on-goto",
            -- Toggles automatic sidebar resizing (see sidebar.auto_resize).
            ["t="] = "toggle-auto-resize",
            -- Decrease auto resize max width by 5. Works with a count.
            ["t["] = "decrease-max-width",
            -- Increase auto resize max width by 5. Works with a count.
            ["t]"] = "increase-max-width",

            -- Toggle fold of the symbol under the cursor.
            ["<2-LeftMouse>"] = "toggle-fold",

            -- Close the sidebar window.
            ["q"] = "close",

            -- Show help.
            ["?"] = "help",
            ["g?"] = "help",
        },
    },
    providers = {
        lsp = {
            timeout_ms = 1000,
            details = {},
            kinds = { default = {} },
            highlights = {
                ...
                default = { }
            },
        },
        treesitter = {
            details = {},
            kinds = { default = {} },
            highlights = {
                ...
                default = {}
            }
        },
    },
    dev = {
        enabled = false,
        log_level = vim.log.levels.ERROR,
        keymaps = {},
    }
}
```

# API

There is now a (currently very simple) API available to control the Sidebar from LUA

```lua
  ---perform any action defined in SidebarAction
  ---@param act SidebarAction[]
  action = function(act)
    local sidebar = apisupport_getsidebar()
    if sidebar ~= nil and sidebar_actions[act] ~= nil then
      sidebar_actions[act](sidebar)
    end
  end,
  ---manually refresh the symbols in the current sidebar
  refresh_symbols = function()
    local sidebar = apisupport_getsidebar()
    if sidebar ~= nil then
      sidebar:refresh_symbols()
    end
  end
```
The available actions can be obtained by calling

```lua
=require("symbols.config").SidebarAction
```

For example, to unfold the entire tree you would call:

```lua
require("symbols").api.action("unfold-all")
```

# Alternatives

- [aerial.nvim](https://github.com/stevearc/aerial.nvim)
- [outline.nvim](https://github.com/hedyhli/outline.nvim)

