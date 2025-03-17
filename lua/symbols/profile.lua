local log = require("symbols.log")

local prof = {}

prof.ON = false

function prof.time(f, fname, opts)
    opts = opts or {}
    local precise = opts.precise or false

    return function(...)
        if not prof.ON then
            return f(...)
        else
            local start = os.clock()
            local result = f(...)
            local end_ = os.clock()
            local debug_info = debug.getinfo(f, "nS")
            local source = (debug_info.source or "@<unknown>"):sub(2)
            do -- abs path to relative path
                local i, _ = source:find("/lua/symbols/")
                if i ~= nil then
                    source = source:sub(i+1)
                end
            end
            local elapsed = end_ - start
            local elapsed_str
            if precise then
                elapsed_str = string.format("%0.fus", elapsed * 1000000)
            else
                elapsed_str = string.format("%0.fms", elapsed * 1000)
            end
            local msg = string.format(
                "Function %s at %s:%d took %s",
                fname or "<unknown>",
                source,
                debug_info.linedefined,
                elapsed_str
            )
            log.debug(msg)
            return result
        end
    end
end

---@class Timer
---@field start_ integer
---@field end_ integer

prof.Timer = {}
prof.Timer.__index = prof.Timer

---@return Timer
function prof.Timer:new()
    return setmetatable({
        start_ = 0,
        end_ = 0,
    }, self)
end

---@return Timer
function prof.Timer:start()
    assert(self.start_ == 0 and self.end_ == 0)
    self.start_ = os.clock()
    return self
end

---@return Timer
function prof.Timer:stop()
    assert(self.start_ ~= 0 and self.end_ == 0)
    self.end_ = os.clock()
    return self
end

---@return number
function prof.Timer:elapsed_ms()
    return (self.end_ - self.start_) * 1000
end

---@return number
function prof.Timer:elapsed_us()
    return (self.end_ - self.start_) * 1000000
end

return prof
