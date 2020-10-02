
function hello()
end

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

local function _get_cfs_pair()
    local pair_id = '4.2.1139631'
    local pair = cjson.decode(chainhelper:get_nft_asset(pair_id))

    local data = nil

    for _, contract in pairs(pair.describe_with_contract) do
        if contract[1] == '1.16.165' then
            for _, describe in pairs(contract[2]) do
                if describe[1] == "pair" then
                    data = cjson.decode(describe[2])
                    break
                end
            end

            break
        end
    end
    return data
end

function buy_cros_cfs()

    local ba=(contract_base_info.invoker_contract_id == '1.16.138')
    local bb=chainhelper:is_owner()

    assert(ba or bb, "can not be called by other contracts")
    local balance = chainhelper:get_account_balance(contract_base_info.owner,'COCOS')
    local pair = _get_cfs_pair()
    local c=balance/50
    local t=math.floor(c*(pair.t/pair.c))
    local tmin=100
    _invokeContractFunction(CONTRACT_CROSWAP,'exactCocosForToken','CFS',tostring(c),tostring(tmin))
    chainhelper:log('c:'..c..',t:'..t..',tmin:'..tmin)
end


