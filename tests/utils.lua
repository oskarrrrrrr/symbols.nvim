local H = {}

function H.open_file(child, path)
    child.type_keys(":e " .. path .. "<cr>")
end

H.eq = MiniTest.expect.equality

H.new_set = function(child)
    return MiniTest.new_set({
      hooks = {
        pre_case = function()
            child.restart({ "-u", "tests/nvim_test/init.lua" })
            child.bo.readonly = false
        end,
        post_once = child.stop,
      },
    })
end

return H
