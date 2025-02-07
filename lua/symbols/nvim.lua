local nvim = {}

---@param buf integer
---@return boolean
function nvim.buf_get_modifiable(buf)
    return vim.api.nvim_get_option_value("modifiable", { buf = buf })
end

---@param buf integer
---@param value boolean
function nvim.buf_set_modifiable(buf, value)
    vim.api.nvim_set_option_value("modifiable", value, { buf = buf })
end

---@param buf integer
---@param lines string[]
function nvim.buf_set_content(buf, lines)
    local modifiable = nvim.buf_get_modifiable(buf)
    if not modifiable then nvim.buf_set_modifiable(buf, true) end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    if not modifiable then nvim.buf_set_modifiable(buf, false) end
end

---@param win integer
---@param name string
---@param value any
function nvim.win_set_option(win, name, value)
    vim.api.nvim_set_option_value(name, value, { win = win })
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
        buf,
        SIDEBAR_HL_NS,
        self.group,
        self.line-1, self.col_start, self.col_end
    )
end

return nvim
