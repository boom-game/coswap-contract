---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liyunhan.
--- DateTime: 2020/9/29 2:04 PM
---

local CONTRACT_CROSWAP = "contract.croswap"

-- invoke的参数类型
local function _encodeValueType(value)
    local tp = type(value)
    return tp == "number" and 1
            or tp == "string" and 2
            or tp == "boolean" and 3
            or tp == "table" and 4
            or tp == "function" and 5
            or 2
end

-- invoke其它合约的方法
local function _invokeContractFunction(contract_name, function_name, ...)
    local args = {...}
    local value_list = {}

    for i = 1, #args do
        local value = args[i]
        if type(value) == "table" then
            value = cjson.encode(value)
        end

        table.insert(value_list, {
            _encodeValueType(value),
            {v = value},
        })
    end

    value_list = cjson.encode(value_list)

    chainhelper:invoke_contract_function(contract_name, function_name, value_list)
end

function test1(amount)
    _invokeContractFunction(CONTRACT_CROSWAP,'exactCocosForToken','CFS',amount*100000,"100")
end


function test2(amount)
    _invokeContractFunction(CONTRACT_CROSWAP,'exactTokenForCocos','CFS',amount*100000,"100")
end


function cin(amount)
    chainhelper:transfer_from_caller(contract_base_info.owner, amount*100000, 'COCOS', false)
end

function sin(amount)
    chainhelper:transfer_from_caller(contract_base_info.owner, amount*100000, 'CFS', false)
end