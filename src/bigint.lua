local POSI = 43 -- +
local NEGA = 45 -- -
local POINT = 46 -- .
local ZERO = 48 -- 0
local NINE = 57 -- 9
local EXP = 101 -- e

local P_DENO = 1000000000000000000
local ACCURACY = 18

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

-- type number: math.floor(number)
-- type string: match("^[\\-\\+]?[0-9\\.]?$")
function toBigInteger(num)
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

local function _comparePart(a, aStart, aEnd, b, bStart, bEnd)
    local aLength = aEnd - aStart + 1
    local bLength = bEnd - bStart + 1

    if aLength > bLength then
        return 1
    elseif aLength < bLength then
        return -1
    end

    for i = 0, aLength - 1 do
        local temp = a[aStart + i] - b[bStart + i]
        if temp < 0 then
            return -1
        elseif temp > 0 then
            return 1
        end
    end

    return 0
end

-- a < b return -1
-- a > b return 1
-- a == b return 0
function compareInt(a, b)
    a = toBigInteger(a)
    b = toBigInteger(b)

    local bsa = _stringToBytes(a)
    local bsb = _stringToBytes(b)
    local pa = bsa[1] ~= NEGA
    local pb = bsb[1] ~= NEGA

    if not pa and pb then
        return -1
    elseif pa and not pb then
        return 1
    end

    local result = _comparePart(bsa, pa and 1 or 2, #bsa,
            bsb, pb and 1 or 2, #bsb)

    return pa and result or -result
end

local function _subPart(a, aStart, aEnd, b, bStart, bEnd, change)
    local def = a[aStart] >= ZERO and ZERO or 0

    local c = {}
    local carry = 0

    for i = 0, aEnd - aStart do
        local temp = a[aEnd - i] - (b[bEnd - i] or def) - carry

        if temp < 0 then
            carry = 1
            temp = temp + 10
        else
            carry = 0
        end

        table.insert(c, 1, temp)
    end

    if change then
        for i = 1, #c do
            a[aStart + i - 1] = c[i]
        end
    end

    while c[1] == 0 do
        table.remove(c, 1)
    end

    return c
end

function subInt(a, b)
    a = toBigInteger(a)
    b = toBigInteger(b)

    local bsa = _stringToBytes(a)
    local bsb = _stringToBytes(b)
    local pa = bsa[1] ~= NEGA
    local pb = bsb[1] ~= NEGA

    if not pa and pb then
        return addInt(a, "-" .. b)
    elseif pa and not pb then
        return addInt(a, string.sub(b, 2))
    end

    if not pa then
        table.remove(bsa, 1)
        table.remove(bsb, 1)
    end

    local cmp = _comparePart(bsa, 1, #bsa, bsb, 1, #bsb)

    if cmp == 0 then
        return "0"
    elseif cmp < 0 then
        pa = not pa
        bsa, bsb = bsb, bsa
    end

    local c = _subPart(bsa, 1, #bsa, bsb, 1, #bsb)
    local bsc = {}

    for i = 1, #c do
        bsc[i] = c[i] + ZERO
    end

    if not pa then
        table.insert(bsc, 1, NEGA)
    end

    return _bytesToString(bsc)
end

function addInt(a, b)
    a = toBigInteger(a)
    b = toBigInteger(b)

    local la = #a
    local lb = #b
    local bsa = _stringToBytes(a)
    local bsb = _stringToBytes(b)
    local pa = bsa[1] ~= NEGA
    local pb = bsb[1] ~= NEGA

    if not pa and pb then
        return subInt(b, string.sub(a, 2))
    elseif pa and not pb then
        return subInt(a, string.sub(b, 2))
    end

    if not pa then
        table.remove(bsa, 1)
        table.remove(bsb, 1)
        la = la - 1
        lb = lb - 1
    end

    local length = math.max(la, lb)

    local bsc = {}
    local carry = 0

    for i = 0, length - 1 do
        local temp = (bsa[la - i] or ZERO) - ZERO
                + (bsb[lb - i] or ZERO) - ZERO + carry

        if temp > 9 then
            carry = 1
            temp = temp - 10
        else
            carry = 0
        end

        table.insert(bsc, 1, temp + ZERO)
    end

    if carry > 0 then
        table.insert(bsc, 1, carry + ZERO)
    end

    if not pa then
        table.insert(bsc, 1, NEGA)
    end

    return _bytesToString(bsc)
end





local function _mul(a, b)
    a = toBigInteger(a)
    b = toBigInteger(b)

    if a == "0" or b == "0" then
        return "0"
    end

    local la = #a
    local lb = #b
    local bsa = _stringToBytes(a)
    local bsb = _stringToBytes(b)
    local pa = bsa[1] ~= NEGA
    local pb = bsb[1] ~= NEGA

    if not pa then
        table.remove(bsa, 1)
        la = la - 1
    end

    if not pb then
        table.remove(bsb, 1)
        lb = lb - 1
    end

    local c = {}
    for i = 1, la do
        for j = 1, lb do
            local temp = (bsa[i] - ZERO) * (bsb[j] - ZERO)
            local index = la - i + lb - j + 1
            c[index] = (c[index] or 0) + temp

            while c[index] and c[index] > 9 do
                c[index + 1] = (c[index + 1] or 0) + math.floor(c[index] / 10)
                c[index] = c[index] % 10
                index = index + 1
            end
        end
    end

    local bsc = {}
    for i = #c, 1, -1 do
        table.insert(bsc, c[i] + ZERO)
    end

    if pa ~= pb then
        table.insert(bsc, 1, NEGA)
    end

    return _bytesToString(bsc)
end

local function _div(a, b)
    a = toBigInteger(a)
    b = toBigInteger(b)

    assert(b ~= "0", "divide by zero")

    if a == "0" then
        return "0"
    end

    local la = #a
    local lb = #b
    local bsa = _stringToBytes(a)
    local bsb = _stringToBytes(b)
    local pa = bsa[1] ~= NEGA
    local pb = bsb[1] ~= NEGA

    if not pa then
        table.remove(bsa, 1)
        la = la - 1
    end

    if not pb then
        table.remove(bsb, 1)
        lb = lb - 1
    end

    if _comparePart(bsa, 1, la, bsb, 1, lb) < 0 then
        return "0"
    end

    for i = 1, #bsa do
        bsa[i] = bsa[i] - ZERO
    end

    for i = 1, #bsb do
        bsb[i] = bsb[i] - ZERO
    end

    local c = {}
    for i = 1, la - lb + 1 do
        local temp = 0

        while i > 1 and bsa[i - 1] > 0 or _comparePart(bsa, i, i + lb - 1, bsb, 1, lb) >= 0 do
            local startIndex = i > 1 and bsa[i - 1] > 0 and i - 1 or i
            _subPart(bsa, startIndex, i + lb - 1, bsb, 1, lb, true)
            temp = temp + 1
        end

        table.insert(c, temp)
    end

    local startIndex = 1
    while c[startIndex] == 0 do
        startIndex = startIndex + 1
    end

    local bsc = {}
    for i = startIndex, #c do
        bsc[i - startIndex + 1] = c[i] + ZERO
    end

    if pa ~= pb then
        table.insert(bsc, 1, NEGA)
    end

    return _bytesToString(bsc)
end

local function split( str,reps )
    local resultStrList = {}
    string.gsub(str,'[^'..reps..']+',function ( w )
        table.insert(resultStrList,w)
    end)
    return resultStrList
end

local function _parseNumber(a)
    a=tostring(a)
    ta=split(a,'.')
    local lta = #ta
    assert(lta>0 and lta<3, "not number")
    if(lta==1) then
        table.insert (ta,'0')
    end
    ta[2]= string.reverse(toBigInteger(string.reverse(ta[2])))

    bsa1=_stringToBytes(ta[1])
    bsa2=_stringToBytes(ta[2])

    for k, v in pairs(bsa1) do
        if(k~=1) then
            assert(v>=48 and v<=57,"not number")
        else
            assert((v>=48 and v<=57) or (v==43) or (v==45),"not number")
        end
    end

    for k, v in pairs(bsa2) do
        assert(v>=48 and v<=57,"not number")
    end
    return ta;
end

function toDecimal(num,tail)
    local ta=_parseNumber(num)
    return ta[1].."."..string.sub(ta[2],1,tail)
end


local function parseNumber(a,b)
    local ta=_parseNumber(a)
    local tb=_parseNumber(b)

    local lta = #ta
    local ltb = #tb

    local ldta=#ta[2]
    local ldtb=#tb[2]

    local maxld=math.max(ldta,ldtb)

    for i = 1, (maxld-ldta) do
        ta[2]=ta[2]..'0'
    end

    for i = 1, (maxld-ldtb) do
        tb[2]=tb[2]..'0'
    end

    local na=ta[1]..ta[2]
    local nb=tb[1]..tb[2]

    local ret = {}
    ret.a=na
    ret.b=nb
    ret.maxld=maxld
    return ret
end


local function _formatResult(tr,pos)
    --补0判定
    local bu=2
    --补0位置
    local bupos=1
    if(tr[1]==NEGA or tr[1]==POSI) then
        bu=3
        bupos=2
    end
    if(pos<bu) then
        for i = 1, bu-pos do
            pos = pos + 1
            table.insert(tr,bupos,ZERO)
        end
    end
    local ltr=#tr
    table.insert(tr,pos,POINT)
    local fret=_bytesToString(tr)

    local ret = _bytesToString(tr)
    if(ltr-pos>ACCURACY) then
        ret=string.sub(ret,1,pos+ACCURACY)
    end
    return ret
end


function add(a,b)
    local dnum=parseNumber(a,b)
    local na=dnum.a
    local nb=dnum.b
    local tmp = addInt(na,nb)
    local tr = _stringToBytes(tmp)
    local ltr=#tr
    local pos=1+ltr-dnum.maxld
    return _formatResult(tr,pos)
end

function sub(a,b)
    local dnum=parseNumber(a,b)
    local na=dnum.a
    local nb=dnum.b
    local tmp = subInt(na,nb)
    local tr = _stringToBytes(tmp)
    local ltr=#tr
    local pos=1+ltr-dnum.maxld
    return _formatResult(tr,pos)
end



function mul(a,b)
    local dnum=parseNumber(a,b)
    local na=dnum.a
    local nb=dnum.b
    local tmp = _mul(na,nb)
    local tr = _stringToBytes(tmp)
    local ltr=#tr
    local pos=1+ltr-2*dnum.maxld
    return _formatResult(tr,pos)
end

function div(a,b)
    local dnum=parseNumber(a,b)
    local na=dnum.a
    local nb=dnum.b
    local tmp = _div(_mul(na,P_DENO),nb)
    local tr = _stringToBytes(tmp)
    local ltr=#tr
    local pos=1+ltr-ACCURACY
    return _formatResult(tr,pos)
end

function compare(a,b)
    local dnum=parseNumber(a,b)
    local na=dnum.a
    local nb=dnum.b
    local tmp = compareInt(na,nb)
    return tmp
end
