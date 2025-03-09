local N = 10000000

-- do
--     local s = os.clock()
--     local t1 = {}
--     for _=1,N do
--         t1[#t1+1] = {
--             some_property = false,
--         }
--     end
--     local e = os.clock()
--     print(string.format("t1: %f", (e-s)*1000))
--
--     local s = os.clock()
--     for i=1,N do
--         t1[i].some_property = true
--     end
--     local e = os.clock()
--     print(string.format("t1: %f", (e-s)*1000))
-- end

do
    local s = os.clock()
    local t2 = {}
    for _=1,N do
        t2[#t2+1] = false
    end
    local e = os.clock()
    print(string.format("t2: %f", (e-s)*1000))

    local s = os.clock()
    for i=1,N do
        t2[i] = true
    end
    local e = os.clock()
    print(string.format("t2: %f", (e-s)*1000))
end

do
    local s = os.clock()
    local t3 = {}
    local e = os.clock()
    print(string.format("t3: %f", (e-s)*1000))

    local s = os.clock()
    for i=1,N do
        t3[i] = true
    end
    local e = os.clock()
    print(string.format("t3: %f", (e-s)*1000))
end

do
    local t = {}
    for _=1,N do
        t[#t+1] = false
    end

    local s = os.clock()
    local x = false
    for i=1,N do
        x = x or t[i]
    end
    local e = os.clock()
    print(string.format("no fun: %f", (e-s)*1000))


    local t = {}
    for _=1,N do
        t[#t+1] = false
    end

    local function get(tbl, idx)
        return tbl[idx] or false
    end

    local s = os.clock()
    local x = false
    for i=1,N do
        x = x or get(t, i)
    end
    local e = os.clock()
    print(string.format("fun: %f", (e-s)*1000))
end
