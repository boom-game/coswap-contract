local Convert = function (Text,Action,Shift)
    local function Check(C) --Checker For Check If Current Letters Is A-Z or a-z .
        if string.byte(C) >= 65 and string.byte(C) <= 90 then
            return "U" --string.upper
        elseif string.byte(C) >= 97 and string.byte(C) <= 122 then
            return "L" --string.lower
        end
    end
    Shift = Shift%26
    if Shift == 0 then Shift = 26 end
    local Enc = function (a,b)
        local Byte = (string.byte(a)-b+Shift)%26
        if Byte == 0 then Byte = 26 end
        return string.char(Byte+b)
    end
    local Dec = function (a,b)
        local Byte = (string.byte(a)-b-Shift)%26
        if Byte == 0 then Byte = 26 end
        return string.char(Byte+b)
    end
    local E , Activity = ""
    if tostring(Action) == "Enc" then
        Activity = Enc
    elseif tostring(Action) == "Dec" then
        Activity = Dec
    else
        print("Error : Action Not Selected")
        os.exit()
    end
    for I = 1,#Text do
        local C = string.sub(Text,I,I)
        local Checked = Check(C)
        if Checked == "U" then
            E = E..Activity(C,64)
        elseif Checked == "L" then
            E = E..Activity(C,96)
        else
            E = E..C
        end
    end
    return E
end


local String = "Hello World !"
local Enc = Convert(String,"Enc",3)
local Dec = Convert(Enc,"Dec",3)

print("Encoded : "..Enc.."\nDecode : "..Dec)

