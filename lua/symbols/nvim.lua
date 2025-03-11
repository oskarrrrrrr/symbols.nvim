local nvim = {}

---@param buf integer
---@param opt string
---@return any
function nvim.buf_get_option(buf, opt)
    return vim.api.nvim_get_option_value(opt, { buf = buf })
end

---@param buf integer
---@param opt string
---@param value any
function nvim.buf_set_option(buf, opt, value)
    vim.api.nvim_set_option_value(opt, value, { buf = buf })
end

---@param buf integer
---@return boolean
function nvim.buf_get_modifiable(buf)
    return nvim.buf_get_option(buf, "modifiable")
end

---@param buf integer
---@param value boolean
function nvim.buf_set_modifiable(buf, value)
    nvim.buf_set_option(buf, "modifiable", value)
end

---@param buf integer
---@param lines string[]
function nvim.buf_set_content(buf, lines)
    local modifiable = nvim.buf_get_modifiable(buf)
    if not modifiable then nvim.buf_set_modifiable(buf, true) end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    if not modifiable then nvim.buf_set_modifiable(buf, false) end
end

---@param buf integer
function nvim.buf_clear_content(buf)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
end

---@param buf integer
---@param start integer
---@param count integer
function nvim.buf_remove_lines(buf, start, count)
    vim.api.nvim_buf_set_lines(buf, start, start+count, true, {})
end

---@param buf integer
---@param start integer
---@param lines string[]
function nvim.buf_set_lines(buf, start, lines)
    vim.api.nvim_buf_set_lines(buf, start, start+(#lines)-1, true, lines)
end

---@param win integer
---@param name string
---@param value any
function nvim.win_set_option(win, name, value)
    vim.api.nvim_set_option_value(name, value, { win = win })
end

---@param win integer
---@return string[]
function nvim.win_get_visible_lines(win)
    local top_line, bottom_line = vim.fn.line("w0", win), vim.fn.line("w$", win)
    local buf = vim.api.nvim_win_get_buf(win)
    return vim.api.nvim_buf_get_lines(buf, top_line-1, bottom_line, true)
end

---@class Highlight
---@field group string
---@field line integer  -- one-indexed
---@field col_start integer
---@field col_end integer
local Highlight = {}
Highlight.__index = Highlight
nvim.Highlight = Highlight

---@param obj table
---@return Highlight
function Highlight:new(obj)
    return setmetatable(obj, self)
end

local SIDEBAR_HL_NS = vim.api.nvim_create_namespace("SymbolsSidebarHl")

---@param buf integer
function Highlight:apply(buf)
    vim.api.nvim_buf_add_highlight(
        buf, SIDEBAR_HL_NS, self.group, self.line-1, self.col_start, self.col_end
    )
end

return nvim
