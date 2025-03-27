local symbols = require("symbols")
local a = symbols.a

vim.keymap.set(
    "n", "s",
    a.sync(function()
        local sb = symbols.api.sidebar_get()
        a.wait(symbols.api.sidebar_open(sb))
        symbols.api.sidebar_change_view(sb, "search")
    end)
)

vim.keymap.set(
    "n", "zm",
    function()
        local sb = symbols.api.sidebar_get()
        if symbols.api.sidebar_visible(sb) then
            local count = math.max(vim.v.count, 1)
            symbols.api.sidebar_symbols_fold(sb, count)
        end
        pcall(vim.cmd, "normal! zm")
    end
)

vim.keymap.set(
    "n", "zM",
    function()
        local sb = symbols.api.sidebar_get()
        if symbols.api.sidebar_visible(sb) then
            symbols.api.sidebar_symbols_fold_all(sb)
        end
        pcall(vim.cmd, "normal! zM")
    end
)


vim.keymap.set(
    "n", "zr",
    function()
        local sb = symbols.api.sidebar_get()
        if symbols.api.sidebar_visible(sb) then
            local count = math.max(vim.v.count, 1)
            symbols.api.sidebar_symbols_unfold(sb, count)
        end
        pcall(vim.cmd, "normal! zr")
    end
)

vim.keymap.set(
    "n", "zR",
    function()
        local sb = symbols.api.sidebar_get()
        if symbols.api.sidebar_visible(sb) then
            symbols.api.sidebar_symbols_unfold_all(sb)
        end
        pcall(vim.cmd, "normal! zR")
    end
)

vim.keymap.set(
    "n", "zo",
    function()
        local sb = symbols.api.sidebar_get()
        if symbols.api.sidebar_visible(sb) then
            symbols.api.sidebar_symbols_unfold_current(sb)
        end
        pcall(vim.cmd, "normal! zo")
    end
)

vim.keymap.set(
    "n", "zO",
    function()
        local sb = symbols.api.sidebar_get()
        if symbols.api.sidebar_visible(sb) then
            symbols.api.sidebar_symbols_unfold_current(sb, true)
        end
        pcall(vim.cmd, "normal! zO")
    end
)

vim.keymap.set(
    "n", "zc",
    function()
        local sb = symbols.api.sidebar_get()
        if symbols.api.sidebar_visible(sb) then
            if (
                symbols.api.sidebar_symbols_current_visible_children(sb) == 0
                or symbols.api.sidebar_symbols_current_folded(sb)
            ) then
                symbols.api.sidebar_symbols_goto_parent(sb)
            else
                symbols.api.sidebar_symbols_fold_current(sb)
            end
        end
        pcall(vim.cmd, "normal! zc")
    end
)

vim.keymap.set(
    "n", "zC",
    function()
        local sb = symbols.api.sidebar_get()
        if symbols.api.sidebar_visible(sb) then
            symbols.api.sidebar_symbols_fold_current(sb, true)
        end
        pcall(vim.cmd, "normal! zC")
    end
)

vim.keymap.set(
    "n", "<C-j>",
    function()
        local sb = symbols.api.sidebar_get()
        if symbols.api.sidebar_visible(sb) then
            symbols.api.sidebar_focus(sb)
            local win = symbols.api.sidebar_win(sb)
            local sidebar_line_count = vim.fn.line("$", win)
            local pos = vim.api.nvim_win_get_cursor(0)
            local count = math.max(vim.v.count, 1)
            local new_cursor_row = math.min(sidebar_line_count, pos[1] + count)
            pcall(vim.api.nvim_win_set_cursor, 0, {new_cursor_row, pos[2]})
            symbols.api.sidebar_symbols_peek_current(sb)
            symbols.api.sidebar_focus_source(sb)
        end
    end
)

vim.keymap.set(
    "n", "<C-k>",
    function()
        local sb = symbols.api.sidebar_get()
        if symbols.api.sidebar_visible(sb) then
            symbols.api.sidebar_focus(sb)
            local count = math.max(vim.v.count, 1)
            local pos = vim.api.nvim_win_get_cursor(0)
            local new_cursor_row = math.max(1, pos[1] - count)
            pcall(vim.api.nvim_win_set_cursor, 0, {new_cursor_row, pos[2]})
            symbols.api.sidebar_symbols_peek_current(sb)
            symbols.api.sidebar_focus_source(sb)
        end
    end
)
