local utils = require("symbols.utils")

local M = {}

---@type integer
M.DEFAULT_LOG_LEVEL = vim.log.levels.ERROR
M.LOG_LEVEL = M.DEFAULT_LOG_LEVEL

---@type table<integer, string>
M.LOG_LEVEL_STRING = {
    [vim.log.levels.ERROR] = "ERROR",
    [vim.log.levels.WARN] = "WARN",
    [vim.log.levels.INFO] = "INFO",
    [vim.log.levels.DEBUG] = "DEBUG",
    [vim.log.levels.TRACE] = "TRACE",
}

---@type table<integer, string>
M.LOG_LEVEL_CMD_STRING = {
    [vim.log.levels.ERROR] = "error",
    [vim.log.levels.WARN] = "warning",
    [vim.log.levels.INFO] = "info",
    [vim.log.levels.DEBUG] = "debug",
    [vim.log.levels.TRACE] = "trace",
    [vim.log.levels.OFF] = "off",
}

M.CMD_STRING_LOG_LEVEL = utils.tbl_reverse(M.LOG_LEVEL_CMD_STRING)

---@param msg string
---@param level any
local function _log(msg, level)
    if level >= M.LOG_LEVEL then
        local date = os.date("%Y/%m/%d %H:%M:%S")
        local fun = ""
        if level == vim.log.levels.TRACE then
            local name = debug.getinfo(3, "n").name or "<anonymous>"
            fun = "(" .. name .. ") "
        end
        local _msg = table.concat({"[", date, "] ", M.LOG_LEVEL_STRING[level], " ", fun, msg}, "")
        vim.notify(_msg, level)
    end
end

function M.error(msg) _log(msg or "", vim.log.levels.ERROR) end
function M.warn(msg)  _log(msg or "", vim.log.levels.WARN)  end
function M.info(msg)  _log(msg or "", vim.log.levels.INFO)  end
function M.debug(msg) _log(msg or "", vim.log.levels.DEBUG) end
function M.trace(msg) _log(msg or "", vim.log.levels.TRACE) end

---@param name string
---@param desc string
---@param create_user_command fun(name: string, cmd: fun(t: table), opts: table)
function M.create_change_log_level_user_command(name, desc, create_user_command)
    local log_levels = vim.tbl_keys(M.CMD_STRING_LOG_LEVEL)
    create_user_command(
        name,
        function(e)
            local arg = e.fargs[1]
            local new_log_level = M.CMD_STRING_LOG_LEVEL[arg]
            if new_log_level == nil then
                M.error("Invalid log level: " .. arg)
            else
                M.LOG_LEVEL = new_log_level
            end
        end,
        {
            nargs = 1,
            complete = function(arg, _)
                local suggestions = {}
                for _, log_level in ipairs(log_levels) do
                    if vim.startswith(log_level, arg) then
                        table.insert(suggestions, log_level)
                    end
                end
                return suggestions
            end,
            desc = desc
        }
    )
end

function M.time(f, fname)
    return function(...)
        local start = os.clock()
        local result = f(...)
        local end_ = os.clock()
        local debug_info = debug.getinfo(f, "nS")
        local msg = string.format(
            "Function %s at %s:%d took %0.fms",
            fname or "<unknown>",
            (debug_info.source or "@<unknown>"):sub(2),
            debug_info.linedefined,
            (end_ - start) * 1000
        )
        M.debug(msg)
        return result
    end
end

return M
