local symbols = require("symbols")
local a = symbols.a

vim.keymap.set(
    "n", "s",
    a.sync(function()
        local sb = Symbols.sidebar.get()
        a.wait(Symbols.sidebar.open(sb))
        Symbols.sidebar.change_view(sb, "search")
    end)
)

vim.keymap.set(
    "n", "zm",
    function()
        local sb = Symbols.sidebar.get()
        if Symbols.sidebar.visible(sb) then
            local count = math.max(vim.v.count, 1)
            Symbols.sidebar.symbols.fold(sb, count)
        end
        pcall(vim.cmd, "normal! zm")
    end
)

vim.keymap.set(
    "n", "zM",
    function()
        local sb = Symbols.sidebar.get()
        if Symbols.sidebar.visible(sb) then
            Symbols.sidebar.symbols.fold_all(sb)
        end
        pcall(vim.cmd, "normal! zM")
    end
)


vim.keymap.set(
    "n", "zr",
    function()
        local sb = Symbols.sidebar.get()
        if Symbols.sidebar.visible(sb) then
            local count = math.max(vim.v.count, 1)
            Symbols.sidebar.symbols.unfold(sb, count)
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

vim.keymap.set(
    "n", "<C-j>",
    function()
        local sb = Symbols.sidebar.get()
        if Symbols.sidebar.visible(sb) then
            Symbols.sidebar.focus(sb)
            local win = Symbols.sidebar.win(sb)
            local sidebar_line_count = vim.fn.line("$", win)
            local pos = vim.api.nvim_win_get_cursor(0)
            local count = math.max(vim.v.count, 1)
            local new_cursor_row = math.min(sidebar_line_count, pos[1] + count)
            pcall(vim.api.nvim_win_set_cursor, 0, {new_cursor_row, pos[2]})
            Symbols.sidebar.symbols.current_peek(sb)
            Symbols.sidebar.focus_source(sb)
        end
    end
)

vim.keymap.set(
    "n", "<C-k>",
    function()
        local sb = Symbols.sidebar.get()
        if Symbols.sidebar.visible(sb) then
            Symbols.sidebar.focus(sb)
            local win = Symbols.sidebar.win(sb)
            local count = math.max(vim.v.count, 1)
            local pos = vim.api.nvim_win_get_cursor(0)
            local new_cursor_row = math.max(1, pos[1] - count)
            pcall(vim.api.nvim_win_set_cursor, 0, {new_cursor_row, pos[2]})
            Symbols.sidebar.symbols.current_peek(sb)
            Symbols.sidebar.focus_source(sb)
        end
    end
)
