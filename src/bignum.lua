local POSI = 43 -- +
local NEGA = 45 -- -
local POINT = 46 -- .
local ZERO = 48 -- 0
local NINE = 57 -- 9
local EXP = 101 -- e

local P_DENO = 10000000000
local ACCURACY = 10


local function _bytesToString(bytes)
    -- return string.char(table.unpack(bytes))

    local str = ""
    for i = 1, #bytes do
        str = str .. string.char(bytes[i])
    end

    return str
end

local function _stringToBytes(str)
    return {string.byte(str, 1, #str)}
end

function toBigNumber(num)
    if type(num) == "number" then
        local str = tostring(math.floor(num))
        local bs = {string.byte(str, 1, #str)}

        local hasExp = false
        for i, b in pairs(bs) do
            if b == EXP then
                hasExp = true
                break
            end
        end

        if not hasExp then
            return str
        end

        if num < 1 and num > -1 then
            return "0"
        end

        local isNeg = false
        if num < 0 then
            isNeg = true
            num = -num
        end

        local bytes = {}

        while num >= 1 do
            local b = math.floor(num % 10)
            num = num / 10
            table.insert(bytes, 1, b + ZERO)
        end

        if isNeg then
            table.insert(bytes, 1, NEGA)
        end

        return _bytesToString(bytes)
    elseif type(num) == "string" then
        local bytes = _stringToBytes(num)

        local startIndex = 1
        local isNeg = false

        if bytes[1] == POSI then
            startIndex = 2
        elseif bytes[1] == NEGA then
            startIndex = 2
            isNeg = true
        end

        local result = {}

        for i = startIndex, #bytes do
            local bt = bytes[i]
            if bt == POINT then
                break
            end

            assert(bt >= ZERO and bt <= NINE, "string must match ^\\-?[0-9\\.]+$")

            if bt > ZERO or #result > 0 then
                table.insert(result, bt)
            end
        end

        if #result == 0 then
            return "0"
        end

        if isNeg then
            table.insert(result, 1, NEGA)
        end

        return _bytesToString(result)
    else
        assert(false, "support type number and string")
    end
end
