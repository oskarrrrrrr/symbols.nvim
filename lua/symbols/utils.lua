local utils = {}

utils.MAX_INT = 2147483647

---@generic K, V
---@param tbl table<K, V>
---@return table<V, K>
function utils.tbl_reverse(tbl)
    local rev = {}
    for k, v in pairs(tbl) do
        assert(rev[v] == nil, "to reverse a map values must be unique")
        rev[v] = k
    end
    return rev
end

---@generic T
---@param l1 T[]
---@param l2 T[]
---@return T[]
function utils.list_diff(l1, l2)
    local diff = {}
    for _, v in ipairs(l1) do
        if not vim.tbl_contains(l2, v) then
            table.insert(diff, v)
        end
    end
    return diff
end

---@param list string[]
---@param enum table<string, string>
---@param list_name string
function utils.assert_list_is_enum(list, enum, list_name)
    local expected = vim.tbl_values(enum)
    local actual_extra = utils.list_diff(list, expected)
    if #actual_extra > 0 then
        assert(false, "Invalid values in array " .. list_name .. ": " .. vim.inspect(actual_extra))
    end
    local expected_extra = utils.list_diff(expected, list)
    if #expected_extra > 0 then
        assert(false, "Missing values in array " .. list_name .. ": " .. vim.inspect(expected_extra))
    end
end

---@param tbl table<string, any>
---@param enum table<string, string>
---@param table_name string
function utils.assert_keys_are_enum(tbl, enum, table_name)
    local actual = vim.tbl_keys(tbl)
    local expected = vim.tbl_values(enum)
    local actual_extra = utils.list_diff(actual, expected)
    if #actual_extra > 0 then
        assert(false, "Invalid keys in table " .. table_name .. ": " .. vim.inspect(actual_extra))
    end
    local expected_extra = utils.list_diff(expected, actual)
    if #expected_extra > 0 then
        assert(false, "Missing keys in table " .. table_name .. ": " .. vim.inspect(expected_extra))
    end
end

return utils
