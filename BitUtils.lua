--[[
封装一些位操作的工具函数
]] --

-- 防止覆盖原有的bit库
bit = bit or {}

-- 位操作: 左移
local function bit_lshift(a, n)
    return a * (2 ^ n)
end

-- 位操作: 右移
local function bit_rshift(a, n)
    return math.floor(a / (2 ^ n))
end

-- 位操作: 与
local function bit_and(a, b)
    local result = 0
    local value = 1
    while a > 0 and b > 0 do
        if a % 2 == 1 and b % 2 == 1 then
            result = result + value
        end
        a = math.floor(a / 2)
        b = math.floor(b / 2)
        value = value * 2
    end
    return result
end

-- 位操作: 或
local function bit_or(a, b)
    local result = 0
    local value = 1
    while a > 0 or b > 0 do
        if a % 2 == 1 or b % 2 == 1 then
            result = result + value
        end
        a = math.floor(a / 2)
        b = math.floor(b / 2)
        value = value * 2
    end
    return result
end

-- 位操作: 异或
local function bit_xor(a, b)
    local result = 0
    local value = 1
    while a > 0 or b > 0 do
        local aa = a % 2
        local bb = b % 2
        if aa ~= bb then
            result = result + value
        end
        a = math.floor(a / 2)
        b = math.floor(b / 2)
        value = value * 2
    end
    return result
end

-- 位操作: 按位读
local function bit_get(value, start, step)
    if not step then
        step = 1
    end
    local endIdx = start + step - 1
    if start < 1 or endIdx > 32 or start > endIdx then
        print("bit_get: Invalid start or step")
        return nil
    end

    local bits = {}
    for i = start, endIdx do
        local bitVal = bit_and(value, 2 ^ (i - 1))
        table.insert(bits, bitVal > 0 and 1 or 0)
    end

    local result = 0
    for i, bit in ipairs(bits) do
        if bit == 1 then
            result = result + (2 ^ (i - 1))
        end
    end

    return result
end

-- 位操作: 按位写
local function bit_set(value, newValue, start, step)
    if not step then
        step = 1
    end

    local endIdx = start + step - 1
    if start < 1 or endIdx > 32 or start > endIdx then
        print("bit_set: Invalid start or step")
        return value
    end

    if newValue < 0 or newValue >= 2 ^ step then
        print("bit_set: Invalid newValue")
        return value
    end

    local mask = 0
    for i = start, endIdx do
        mask = mask + (2 ^ (i - 1))
    end
    value = bit_and(value, bit_xor(0xFFFFFFFF, mask))

    -- 设置新值
    for i = start, endIdx do
        local bitVal = bit_and(newValue, 2 ^ (i - start))
        if bitVal > 0 then
            value = bit_or(value, 2 ^ (i - 1))
        end
    end

    return value
end

--- 位操作: 按位读取单个位; 从右往左读取第index位的值
--- @param value number
--- @param index number
--- @return number
--- @usage bit_get_flag(19, 1) -> 1
--- @usage value = 19(10011), index = 1, return 1
local function bit_get_flag(value, index)
    local flag = bit_get(value, index)
    return flag
end

--- 位操作: 按位写入单个位; 从右往左写入第index位的值,写入后返回新值
--- @param value number
--- @param index number
--- @param flag number: 0或1
--- @return number
--- @usage bit_set_flag(19, 1, 0) -> 18
--- @usage value = 19(10011), index = 1, flag = 0, return 18(10010)
local function bit_set_flag(value, index, flag)
    local newValue = bit_set(value, flag, index)
    return newValue
end

--- 位操作: 按位读取多个位; 从右往左第start位开始截取step位，截取后再从左往右读取值
--- @param value number
--- @param start number
--- @param step number
--- @return number
--- @usage bit_get_value(19, 2, 2) -> 1
--- @usage value = 19(10011), start = 2, step = 2, return 1(01)
local function bit_get_value(value, start, step)
    value = bit_get(value, start, step)
    return value
end

--- 位操作: 按位写入多个位; 从右往左第start位开始截取step位,截取后再写入新值,写入后返回新值
--- @param value number
--- @param newValue number
--- @param start number
--- @param step number
--- @return number
--- @usage bit_set_value(19, 3, 1, 2) -> 31
--- @usage value = 19(10011), newValue = 3(11), start = 3, step = 2, return 31(11111)
local function bit_set_value(value, newValue, start, step)
    newValue = bit_set(value, newValue, start, step)
    return newValue
end

--- 位操作: 按索引组读取多个位; 从右往左每bits位为一个索引组，读取第index组内从start位开始的step位的值
--- @param value number
--- @param index number
--- @param bits number
--- @param start number
--- @param step number
--- @return number
--- @usage bit_get_value_by_index(819, 3, 2, 1, 2) -> 3
--- @usage value = 819(1100110011), index = 3, bits = 2, start = 1, step = 2, return 3
local function bit_get_value_by_index(value, index, bits, start, step)
    local startBit = (index - 1) * bits + start
    local result = bit_get_value(value, startBit, step)
    return result
end

--- 位操作: 按索引组写入多个位; 从右往左每bits位为一个索引组，写入第index组内从start位开始的step位的新值,写入后返回新值
--- @param value number
--- @param index number
--- @param bits number
--- @param start number
--- @param step number
--- @param newValue number
--- @return number
--- @usage bit_set_value_by_index(819, 0, 3, 2, 1, 2) -> 771
--- @usage value = 819(1100110011), newValue = 0, index = 3, bits = 2, start = 1, step = 2, return 771(1100000011)
local function bit_set_value_by_index(value, newValue, index, bits, start, step)
    local startBit = (index - 1) * bits + start
    local result = bit_set_value(value, newValue, startBit, step)
    return result
end

bit.lshift = bit.lshift or bit_lshift
bit.rshift = bit.rshift or bit_rshift
bit.band = bit.band or bit_and
bit.bor = bit.bor or bit_or
bit.bxor = bit.bxor or bit_xor
bit.bget = bit.bget or bit_get
bit.bset = bit.bset or bit_set
bit.bgetFlag = bit.bgetFlag or bit_get_flag
bit.bsetFlag = bit.bsetFlag or bit_set_flag
bit.bgetValue = bit.bgetValue or bit_get_value
bit.bsetValue = bit.bsetValue or bit_set_value
bit.bgetValueByIndex = bit.bgetValueByIndex or bit_get_value_by_index
bit.bsetValueByIndex = bit.bsetValueByIndex or bit_set_value_by_index


-- -- test function
-- local describe = {
--     test = function(name, fn)
--         print(name)
--         fn()
--     end
-- }

-- local expect = function(actual)
--     return {
--         toBe = function(value)
--             assert(actual == value)
--         end,
--     }
-- end

-- -- test case
-- -- case 1: bit_lshift
-- describe.test("bit_lshift", function()
--     expect(bit.lshift(1, 1)).toBe(2)
--     expect(bit.lshift(1, 2)).toBe(4)
--     expect(bit.lshift(1, 3)).toBe(8)
--     expect(bit.lshift(1, 4)).toBe(16)
-- end)

-- -- case 2: bit_rshift
-- describe.test("bit_rshift", function()
--     expect(bit.rshift(2, 1)).toBe(1)
--     expect(bit.rshift(4, 2)).toBe(1)
--     expect(bit.rshift(8, 3)).toBe(1)
--     expect(bit.rshift(16, 4)).toBe(1)
-- end)

-- -- case 3: bit_and
-- describe.test("bit_and", function()
--     expect(bit.band(1, 1)).toBe(1)
--     expect(bit.band(1, 0)).toBe(0)
--     expect(bit.band(2, 1)).toBe(0)
--     expect(bit.band(2, 2)).toBe(2)
--     expect(bit.band(3, 2)).toBe(2)
--     expect(bit.band(3, 1)).toBe(1)
-- end)

-- -- case 4: bit_or
-- describe.test("bit_or", function()
--     expect(bit.bor(1, 1)).toBe(1)
--     expect(bit.bor(1, 0)).toBe(1)
--     expect(bit.bor(2, 1)).toBe(3)
--     expect(bit.bor(2, 2)).toBe(2)
--     expect(bit.bor(3, 2)).toBe(3)
--     expect(bit.bor(3, 1)).toBe(3)
-- end)

-- -- case 5: bit_xor
-- describe.test("bit_xor", function()
--     expect(bit.bxor(1, 1)).toBe(0)
--     expect(bit.bxor(1, 0)).toBe(1)
--     expect(bit.bxor(2, 1)).toBe(3)
--     expect(bit.bxor(2, 2)).toBe(0)
--     expect(bit.bxor(3, 2)).toBe(1)
--     expect(bit.bxor(3, 1)).toBe(2)
-- end)

-- -- case 6: bit_get
-- describe.test("bit_get", function()
--     expect(bit.bget(1, 1)).toBe(1)
--     expect(bit.bget(2, 1)).toBe(0)
--     expect(bit.bget(2, 2)).toBe(1)
--     expect(bit.bget(3, 1)).toBe(1)
--     expect(bit.bget(3, 2)).toBe(1)
--     expect(bit.bget(3, 3)).toBe(0)
-- end)

-- -- case 7: bit_set
-- describe.test("bit_set", function()
--     expect(bit.bset(1, 0, 1)).toBe(0)
--     expect(bit.bset(1, 1, 1)).toBe(1)
--     expect(bit.bset(2, 0, 1)).toBe(2)
--     expect(bit.bset(2, 1, 1)).toBe(3)
--     expect(bit.bset(3, 0, 1)).toBe(2)
--     expect(bit.bset(3, 1, 1)).toBe(3)
-- end)

-- -- case 8: bit_get_flag
-- describe.test("bit_get_flag", function()
--     expect(bit.bgetFlag(19, 1)).toBe(1)
--     expect(bit.bgetFlag(19, 2)).toBe(1)
--     expect(bit.bgetFlag(19, 3)).toBe(0)
--     expect(bit.bgetFlag(19, 4)).toBe(0)
--     expect(bit.bgetFlag(19, 5)).toBe(1)
-- end)

-- -- case 9: bit_set_flag
-- describe.test("bit_set_flag", function()
--     expect(bit.bsetFlag(19, 1, 0)).toBe(18)
--     expect(bit.bsetFlag(19, 2, 0)).toBe(17)
--     expect(bit.bsetFlag(19, 3, 0)).toBe(19)
--     expect(bit.bsetFlag(19, 4, 0)).toBe(19)
--     expect(bit.bsetFlag(19, 5, 0)).toBe(3)
-- end)

-- -- case 10: bit_get_value
-- describe.test("bit_get_value", function()
--     expect(bit.bgetValue(19, 1, 1)).toBe(1)
--     expect(bit.bgetValue(19, 2, 1)).toBe(1)
--     expect(bit.bgetValue(19, 3, 1)).toBe(0)
--     expect(bit.bgetValue(19, 4, 1)).toBe(0)
--     expect(bit.bgetValue(19, 5, 1)).toBe(1)
-- end)

-- -- case 11: bit_set_value
-- describe.test("bit_set_value", function()
--     expect(bit.bsetValue(19, 1, 1, 1)).toBe(19)
--     expect(bit.bsetValue(19, 1, 2, 1)).toBe(19)
--     expect(bit.bsetValue(19, 1, 3, 1)).toBe(23) -- 19(10011) -> 10111(23)
--     expect(bit.bsetValue(19, 1, 4, 1)).toBe(27) -- 19(10011) -> 11011(27)
--     expect(bit.bsetValue(19, 1, 5, 1)).toBe(19) -- 19(10011) -> 10011(19)
-- end)

-- -- case 12: bit_get_value_by_index
-- describe.test("bit_get_value_by_index", function()
--     expect(bit.bgetValueByIndex(819, 1, 2, 1, 2)).toBe(3) -- 819(1100110011) -> 3(11)
--     expect(bit.bgetValueByIndex(819, 2, 2, 1, 2)).toBe(0) -- 819(1100110011) -> 0(00)
--     expect(bit.bgetValueByIndex(819, 3, 2, 1, 2)).toBe(3) -- 819(1100110011) -> 3(11)
--     expect(bit.bgetValueByIndex(819, 4, 2, 1, 2)).toBe(0) -- 819(1100110011) -> 0(00)
-- end)

-- -- case 13: bit_set_value_by_index
-- describe.test("bit_set_value_by_index", function()
--     expect(bit.bsetValueByIndex(819, 0, 1, 2, 1, 2)).toBe(816) -- 819(1100110011) -> 1100110000(816)
--     expect(bit.bsetValueByIndex(819, 0, 2, 2, 1, 2)).toBe(819) -- 819(1100110011) -> 1100110011(819)
--     expect(bit.bsetValueByIndex(819, 0, 3, 2, 1, 2)).toBe(771) -- 819(1100110011) -> 1100000011(771)
--     expect(bit.bsetValueByIndex(819, 0, 4, 2, 1, 2)).toBe(819) -- 819(1100110011) -> 1100110011(819)
-- end)
