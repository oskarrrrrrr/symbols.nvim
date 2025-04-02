<!-- panvimdoc-ignore-start -->

# symbols.nvim

Code navigation sidebar. Instantly find your way around any file.

## Features

- **Listing Symbols** - uses LSP servers and Treesitter parsers.
- **Fuzzy Search** - quickly find symbols.
- **Preview Window** - peek at code before jumping, edit in place if needed.
- **Symbol Details** - display symbol details inline or in a pop-up for extra context.
- **Dynamic Settings** - change settings on the fly without restarting Neovim.
- **Custom Display Rules** - configurable filtering and display formatting per language.
- **Preserving Folds** - keeps your sidebar folds in tact on updates (most of the time).
- **Mouse Support** - works with mouse.
- **Lua API** - for powerful keymaps and automations.

https://github.com/user-attachments/assets/6262fa59-a320-4043-a3ba-97617f0fd8b3

<!-- panvimdoc-ignore-end -->

# Requirements

- Neovim 0.10+
- LSP servers for desired languages
- Treesitter parsers (see [Supported Languages](#supported-languages))

# Quick Start

> **Warning**
>
> The main branch is used for development and may introduce breaking changes without warning.
> For a more stable experience use tags with you plugin manager.

Using lazy.nvim:

```lua
{
    "oskarrrrrrr/symbols.nvim",
    config = function()
        local r = require("symbols.recipes")
        require("symbols").setup(
            r.DefaultFilters,
            r.AsciiSymbols,
            {
                sidebar = {
                    -- custom settings here
                    -- e.g. hide_cursor = false
                }
            }
        )
        vim.keymap.set("n", ",s", "<cmd>Symbols<CR>")
        vim.keymap.set("n", ",S", "<cmd>SymbolsClose<CR>")
    end
}
```

Make sure to checkout these sections:
- [Tips](#tips)
- [Configuration](#configuration) (especially the example config with cool keymaps)
- [Lua API](#lua-api) (useful for custom keymaps and automations)

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

<details>
<summary>Example Config With Cool Keymaps</summary>

```lua
local function symbols_setup()
    local symbols = require("symbols")
    local r = require("symbols.recipes")

    symbols.setup(
        r.DefaultFilters,
        r.AsciiSymbols, -- or r.FancySymbols
        { -- custom settings
            sidebar = {
                auto_peek = false,
                cursor_follow = true,
                close_on_goto = false,
                preview = {
                    -- add a convenient keymap
                    keymaps = { ["<cr>"] = "goto-code" }
                },
            },
        }
    )

    -- Example keymaps below.

    -- async, needed for some keymaps
    local a = Symbols.a

    -- Open the sidebar.
    vim.keymap.set("n", ",s", "<cmd>Symbols<CR>")

    -- Close the sidebar.
    vim.keymap.set("n", ",S", "<cmd>SymbolsClose<CR>")

    -- Search in the sidebar. Open the sidebar if it's closed.
    vim.keymap.set(
        "n", "s",
        a.sync(function()
            a.wait(Symbols.sidebar.open(0))
            Symbols.sidebar.view_set(0, "search")
            Symbols.sidebar.focus(0)
        end)
    )

    -- Show current symbol in the sidebar (unfolds symbols if needed).
    -- Opens the sidebar if it's closed. Especially useful with deeply
    -- nested symbols, e.g. when using with JSON files.
    vim.keymap.set(
        "n", "gs",
        a.sync(function()
            a.wait(Symbols.sidebar.open(0))
            Symbols.sidebar.symbols.goto_symbol_under_cursor(0)
            Symbols.sidebar.focus(0)
        end)
    )

    -- The next two mappings move the cursor up/down in the sidebar and peek the symbol
    -- without changing the focused window.

    vim.keymap.set(
        "n", "<C-k>",
        function()
            if not Symbols.sidebar.visible(0) then return end
            Symbols.sidebar.view_set(0, "symbols")
            Symbols.sidebar.focus(0)
            local count = math.max(vim.v.count, 1)
            local pos = vim.api.nvim_win_get_cursor(0)
            local new_cursor_row = math.max(1, pos[1] - count)
            pcall(vim.api.nvim_win_set_cursor, 0, {new_cursor_row, pos[2]})
            Symbols.sidebar.symbols.current_peek(0)
            Symbols.sidebar.focus_source(0)
        end
    )

    vim.keymap.set(
        "n", "<C-j>",
        function()
            if not Symbols.sidebar.visible(0) then return end
            Symbols.sidebar.view_set(0, "symbols")
            Symbols.sidebar.focus(0)
            local win = Symbols.sidebar.win(0)
            local sidebar_line_count = vim.fn.line("$", win)
            local pos = vim.api.nvim_win_get_cursor(0)
            local count = math.max(vim.v.count, 1)
            local new_cursor_row = math.min(sidebar_line_count, pos[1] + count)
            pcall(vim.api.nvim_win_set_cursor, 0, {new_cursor_row, pos[2]})
            Symbols.sidebar.symbols.current_peek(0)
            Symbols.sidebar.focus_source(0)
        end
    )

    -- Below are 8 mappings (zm, Zm, zr, zR, zo, zO, zc, zC) for managing folds.
    -- They modify the sidebar folds and regular vim folds at the same time.
    -- In some cases the behavior might be surprising, for instance, when you
    -- use folds that do not correspond to symbols in the sidebar.

    vim.keymap.set(
        "n", "zm",
        function()
            if Symbols.sidebar.visible(0) then
                local count = math.max(vim.v.count, 1)
                Symbols.sidebar.symbols.fold(0, count)
            end
            pcall(vim.cmd, "normal! zm")
        end
    )

    vim.keymap.set(
        "n", "zM",
        function()
            if Symbols.sidebar.visible(0) then
                Symbols.sidebar.symbols.fold_all(0)
            end
            pcall(vim.cmd, "normal! zM")
        end
    )


    vim.keymap.set(
        "n", "zr",
        function()
            if Symbols.sidebar.visible(0) then
                local count = math.max(vim.v.count, 1)
                Symbols.sidebar.symbols.unfold(0, count)
            end
            pcall(vim.cmd, "normal! zr")
        end
    )

    vim.keymap.set(
        "n", "zR",
        function()
            local sb = Symbols.sidebar.get()
            if Symbols.sidebar.visible(sb) then
                Symbols.sidebar.symbols.unfold_all(sb)
            end
            pcall(vim.cmd, "normal! zR")
        end
    )

    vim.keymap.set(
        "n", "zo",
        function()
            local sb = Symbols.sidebar.get()
            if Symbols.sidebar.visible(sb) then
                Symbols.sidebar.symbols.current_unfold(sb)
            end
            pcall(vim.cmd, "normal! zo")
        end
    )

    vim.keymap.set(
        "n", "zO",
        function()
            local sb = Symbols.sidebar.get()
            if Symbols.sidebar.visible(sb) then
                Symbols.sidebar.symbols.current_unfold(sb, true)
            end
            pcall(vim.cmd, "normal! zO")
        end
    )

    vim.keymap.set(
        "n", "zc",
        function()
            local sb = Symbols.sidebar.get()
            if Symbols.sidebar.visible(sb) then
                if (
                    Symbols.sidebar.symbols.current_visible_children(sb) == 0
                    or Symbols.sidebar.symbols.current_folded(sb)
                ) then
                    Symbols.sidebar.symbols.goto_parent(sb)
                else
                    Symbols.sidebar.symbols.current_fold(sb)
                end
            end
            pcall(vim.cmd, "normal! zc")
        end
    )

    vim.keymap.set(
        "n", "zC",
        function()
            local sb = Symbols.sidebar.get()
            if Symbols.sidebar.visible(sb) then
                Symbols.sidebar.symbols.current_fold(sb, true)
            end
            pcall(vim.cmd, "normal! zC")
        end
    )
end
```

</details>

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
            hl_guides = "Comment",
            -- use this highlight group for the collapse/expand markers
            hl_foldmarker = "String"
        },
        -- highlight group for the inline details shown next to the symbol name
        -- (provider - dependent)
        hl_details = "Comment",
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

# Lua API

> **warning** - Lua API is experimental for now. There might be breaking changes without additional warnings.

A global variable `Symbols` is defined on setup. You can use it instead of `require("symbols")`.

## Constants

**`Symbols.FILE_TYPE_MAIN`**

File type set for the buffer used for symbols tree view.

**`Symbols.FILE_TYPE_SEARCH`**

File type set for the buffer used for symbols search.

**`Symbols.FILE_TYPE_HELP`**

File type set for the buffer used to display help.

## Dev

**`Symbols.log_level_set(level: integer)`**

Use builtin log levels: `vim.log.levels`.

## Async

We expose a simple async library to avoid nested callbacks (aka "callback hell").
Note, you probably don't have to understand exactly how this async implementation works.
There are some nested functions which can get confusing. To save time consider skimming
this section but try to understand the examples.

In this section we refer to wrapped functions, these are the functions wrapped
with `Symbols.a.wrap`. Wrapped functions can be awaited. Most users probably won't
need to wrap any functions themselves.

**`Symbols.a.sync(f: fun())`**

Wrapped functions can be a.wait-ed inside a.sync functions.

**`Symbols.a.wait(f: fun(callback: fun(R...))): R...`**

Runs and waits for a wrapped function to complete. Has to be called within an async function.
Will return any values passed to the callback function.

**`Symbols.a.fire_and_forget(f: fun(callback: fun(...)))`**

Calls a wrapped function `f` and continues execution without waiting for it to
finish. Can be used outside of async functions. Note that it will discard any
return values.

**`Symbols.a.wrap(f: fun(V..., callback: fun(...): ...)): (fun(V...): fun(callback: fun(R...): R...))`**

This function is used internally to expose awaitable functions. Use it to wrap
a callback based function and make it awaitable.

<details>
<summary>Usage Example</summary>

```lua
local a = Symbols.a

-- prints x after t miliseconds and returns x
local delayed_print = a.wrap(function(x, t, callback)
    vim.defer_fn(
        function()
            vim.print(x)
            -- Make sure to call the callback whenever the function is done.
            -- Otherwise, a.wait will wait indefinitely.
            --
            -- Return values can be passed via arguments of the callback.
            callback(x)
        end,
        t
    )
end)

-- a.wait-able functions have to be called from a.sync functions
a.sync(function()
    -- a.fire_and_forget calls delayed_print and continues (without waiting for it to finish).
    a.fire_and_forget(
        delayed_print("This should print last.", 1100)
    )

    -- a.wait calls delayed_print and waits for it to finish.
    local s = a.wait(
        delayed_print("Hellope", 1000)
    )
    vim.print("Got return value: " .. s)

    vim.print("This should print second to last.")
end)() -- Important! Remember to call the async function.

-- Note that fire_and_forget can be used outside of async functions.
a.fire_and_forget(delayed_print("This should print second.", 100))

-- While an a.sync function a.wait-s other code will run in the meantine.
vim.print("This should print first.")
```

</details>

## Sidebar

First parameter to most functions in this section is `sb` of type `symbols.SidebarId`.
It will not be annotated to avoid clutter. Similarly to Neovim Lua API, you can use `0`
to indicate the current sidebar.

**`Symbols.sidebar.get(win: integer?) -> symbols.SidebarId`**

Get sidebar for window `win`. Current window will be used if `win` is skipped.
Passing `win` which is already used by a sidebar is fine and will return its id.
If there is no sidebar for the given window yet then it will be created but not opened.

**`Symbols.sidebar.open(sb)`**

Wrapped function that opens a sidebar. It's safe to call when the sidebar is already open.

<details>
<summary>Example</summary>

```lua
local a = Symbols.a
a.sync(function()
    a.wait(Symbols.sidebar.open(0))
    Symbols.sidebar.symbols.unfold_all(0)
end)()
```

</details>

**`Symbols.sidebar.close(sb)`**

Closes a sidebar.

**`Symbols.sidebar.close_all()`**

Closes all sidebars (in all tabs).

**`Symbols.sidebar.visible(sb): boolean`**

Check whether a sidebar is visible (opened).

**`Symbols.sidebar.win(sb): integer`**

Get the window id of the window in which the sidebar is displayed.

**`Symbols.sidebar.win_source(sb): integer`**

Get the window id of the window with source code.

**`Symbols.sidebar.focus(sb)`**

Set current window to sidebar.

**`Symbols.sidebar.focus_source(sb)`**

Set current window to source code.

**`Symbols.sidebar.cursor_hiding_set(hide_cursor: boolean)`**

Set cursor hiding. Note this is a global setting so `sb` is not needed.

**`Symbols.sidebar.cursor_hiding_toggle()`**

Toggle cursor hiding. Note this is a global setting so `sb` is not needed.

**`Symbols.sidebar.view_set(sb, view: "symbols" | "search")`**

Change sidebar view. Doesn't change the focused window.

**`Symbols.sidebar.view_get(sb): "symbols" | "search"`**

Get current sidebar view.

**`Symbols.sidebar.auto_resize_set(sb, auto_resize: boolean)`**

Enable/disable auto resizing.

**`Symbols.sidebar.auto_resize_toggle(sb)`**

Toggle auto resizing.

**`Symbols.sidebar.auto_resize_get(sb): boolean`**

Get auto resize setting.

**`Symbols.sidebar.width_min_set(sb, min_width: integer)`**

Set minimum width. This setting is relevant only if auto resizing is enabled.

**`Symbols.sidebar.width_min_get(sb): integer`**

Get minimum width. This setting is relevant only if auto resizing is enabled.

**`Symbols.sidebar.width_max_set(sb, max_width: integer)`**

Set maximum width. This setting is relevant only if auto resizing is enabled.

**`Symbols.sidebar.width_max_get(sb): integer`**

Get maximum width. This setting is relevant only if auto resizing is enabled.

**`Symbols.sidebar.filters_enabled_set(sb, filters_enabled: boolean)`**

Enables/disables all filters.

**`Symbols.sidebar.filters_enabled_toggle`**

Toggles all filters.

### Symbols

**`Symbols.sidebar.symbols.force_refresh(sb)`**

Wrapped function that fetches symbols from provider (LSP, Treesitter, etc.)
and renders them in the sidebar.

**`Symbols.sidebar.symbols.fold_all(sb)`**

Folds all symbols.

**`Symbols.sidebar.symbols.unfold_all(sb)`**

Unfolds all symbols.

**`Symbols.sidebar.symbols.unfold(sb, levels: integer?)`**

Unfolds by `levels` levels or 1 if argument skipped.

**`Symbols.sidebar.symbols.fold(sb, levels: integer?)`**

Folds by `levels` levels or 1 if argument skipped.

**`Symbols.sidebar.symbols.goto_symbol_under_cursor(sb)`**

Moves the cursor in the sidebar to the symbol under cursor in the source code window.
Doesn't change the focused window.

**`Symbols.sidebar.symbols.inline_details_show_set(sb, show_inline_details: boolean)`**

Enable/disable inline details.

**`Symbols.sidebar.symbols.inline_details_show_toggle(sb)`**

Toggle inline details.

**`Symbols.sidebar.symbols.details_auto_show_set(sb, auto_show_details: boolean)`**

Enable/disable auto showing of details window.

**`Symbols.sidebar.symbols.details_auto_show_toggle(sb)`**

Toggle auto showing of details window.

**`Symbols.sidebar.symbols.preview_auto_show_set(sb, auto_show_preview: boolean)`**

Enable/disable auto showing of preview window.

**`Symbols.sidebar.symbols.preview_auto_show_toggle(sb)`**

Toggle auto showing of preview window.

**`Symbols.sidebar.symbols_cursor_follow_set(sb, follow_cursor: boolean)`**

Enable/disable following the cursor in the source code window.

**`Symbols.sidebar.symbols_cursor_follow_toggle(sb)`**

Toggle following the cursor in the source code window.

**`Symbols.sidebar.symbols.current_unfold(sb)`**

Unfold the symbol under the cursor in the sidebar.

**`Symbols.sidebar.symbols.current_fold(sb)`**

Fold the symbol under the cursor in the sidebar.

**`Symbols.sidebar.symbols.current_fold_toggle(sb)`**

Toggle fold state of the symbol under the cursor in the sidebar.

**`Symbols.sidebar.symbols.current_folded(sb): boolean`**

Returns true if the symbol under the cursor in the sidebar is folded, false otherwise.

**`Symbols.sidebar.symbols.current_peek(sb)`**

In source code window jump to symbol that is under the cursor in the sidebar.

**`Symbols.sidebar.symbols.current_visible_children(sb): integer`**

Return the number of visible (not filtered out) children of the symbol under cursor
in the sidebar. Can be used to check if it makes sense to fold/unfold symbol.

**`Symbols.sidebar.symbols.goto_parent(sb)`**

Move the cursor in the sidebar to the parent symbol.

**`Symbols.sidebar.symbols.goto_next_symbol_at_level(sb)`**

Move the cursor in the sidebar to the next symbol at the same level.

**`Symbols.sidebar.symbols.goto_prev_symbol_at_level(sb)`**

Move the cursor in the sidebar to the previous symbol at the same level.

# Alternatives

- [aerial.nvim](https://github.com/stevearc/aerial.nvim)
- [outline.nvim](https://github.com/hedyhli/outline.nvim)
