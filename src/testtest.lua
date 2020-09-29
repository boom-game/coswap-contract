local CONTRACT_CROSWAP = "contract.pigoneegg" -- 测试网的croswap合约

local function _encodeValueType(value)
    local tp = type(value)
    return tp == "number" and 1
            or tp == "string" and 2
            or tp == "boolean" and 3
            or tp == "table" and 4
            or tp == "function" and 5
            or 2
end

-- 调用其它合约的方法
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

function testCroswapLP(lp_id)
    -- 校验LP的合法性
    _invokeContractFunction(CONTRACT_CROSWAP, "checkLP", lp_id)

    local lp = cjson.decode(cjson.decode(chainhelper:get_nft_asset(lp_id)).base_describe)
    --[[
    lp的基本数据，样例：
    {
        icon: "http://www.cocoswap.info/swap_token.png",
        liquidity: 300000,
        name: "COCOS-IOST-LP",
        token_symbol: "IOST",
        type: "swap cert",
        version: 3,
    }
    ]]

    local token_symbol = lp.token_symbol -- 凭证对应的代币名字
    local liquidity = lp.liquidity -- 凭证包含的流动性数量

    public_data = {
        lp = lp,
        token_symbol = token_symbol,
        liquidity = liquidity,
    }
    write_list = {
        public_data = {},
    }
    chainhelper:write_chain()
end