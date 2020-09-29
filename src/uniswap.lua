-- 主币
local COCOS_ACCURACY = 100000
local COCOS_ID = "1.3.21"

-- 兑换手续费率（支付端）
local EXCHANGE_FEE_NUME = 3
local EXCHANGE_FEE_DENO = 1000

-- 占比的分母
local P_DENO = 100000000

-- 可接受的币数量的最大值
local TOKEN_AMOUNT_MAX = 1000000000000000000

-- 大整数计算库
local CONTRACT_BIGINTEGER = "contract.biginteger"

-- private 检查整数（字符串）
local function isInteger(str)
    local num = tonumber(str)
    return num and (num - math.floor(num) == 0)
end

-- private 读取链上数据
local function readAll()
    read_list = {
        public_data = {
            pair_set = true,
        }
    }
    chainhelper:read_chain()
end

-- private 写入链上数据
local function writeAll()
    write_list = {
        public_data = {
            pair_set = true,
        }
    }
    chainhelper:write_chain()
end

function clear()
    assert(contract_base_info.invoker_contract_id == "1.16.0",
            "Not to be called by any other contracts!")
    assert(chainhelper:is_owner(), "Unauthorized!")

    public_data.pair_set = {}

    writeAll()
end

-- public 初始化 owner only
function init()
    assert(contract_base_info.invoker_contract_id == "1.16.0",
            "Not to be called by any other contracts!")
    assert(chainhelper:is_owner(), "Unauthorized!")

    readAll()

    public_data.pair_set = public_data.pair_set or {}

    writeAll()
end

local function exactTokenForToken(bi, product, amount0, amount1, delta0)
    local fee = bi.add(bi.div(bi.mul(delta0, EXCHANGE_FEE_NUME), EXCHANGE_FEE_DENO), 1)
    local amount0_ = bi.sub(bi.add(amount0, delta0), fee)
    local amount1_ = bi.div(product, amount0_)
    local delta1 = bi.sub(amount1, amount1_)

    return amount0_, amount1_, delta1, fee
end

local function tokenForExactToken(bi, product, amount0, amount1, delta1)
    local amount1_ = bi.sub(amount1, delta1)
    local amount0_ = bi.div(product, amount1_)
    local delta0 = bi.sub(amount0_, amount0)
    local fee = bi.div(bi.mul(delta0, EXCHANGE_FEE_NUME), EXCHANGE_FEE_DENO - EXCHANGE_FEE_NUME)
    delta0 = bi.add(delta0, fee)

    return amount0_, amount1_, delta0, fee
end

-- public cocos兑换token以cocos为定值
function cocos2TokenConstCocos(token_id, cocos_amount, min_token_amount)
    assert(type(token_id) == "string", "token_id should be string")
    assert(string.sub(token_id, 1, 4) == "1.3.", "token_id should be started with 1.3.")

    assert(isInteger(cocos_amount), "cocos_amount should be integer!")
    cocos_amount = tonumber(cocos_amount)
    assert(cocos_amount > 0 and cocos_amount <= TOKEN_AMOUNT_MAX,
            "cocos_amount should be in (0, " .. TOKEN_AMOUNT_MAX .. "]")

    assert(isInteger(min_token_amount), "min_token_amount should be integer!")
    min_token_amount = tonumber(min_token_amount)
    assert(min_token_amount >= 0 and min_token_amount <= TOKEN_AMOUNT_MAX,
            "min_token_amount should be in [0, " .. TOKEN_AMOUNT_MAX .. "]")

    read_list = {
        public_data = {
            pair_set = true,
        }
    }
    chainhelper:read_chain()

    local pair_info = public_data.pair_set[token_id]
    assert(pair_info, token_id .. " not found!")

    local bi = import_contract(CONTRACT_BIGINTEGER)

    local new_cocos_amount, new_token_amount, token_amount, cocos_fee =
    exactTokenForToken(bi, pair_info.constant_k, pair_info.cocos_amount,
            pair_info.token_amount, cocos_amount)
    assert(bi.compare(new_cocos_amount, TOKEN_AMOUNT_MAX) <= 0,
            "Token amount greater than " .. TOKEN_AMOUNT_MAX)
    assert(bi.compare(new_token_amount, pair_info.token_amount) < 0,
            "Too little to exchange for " .. token_id)
    assert(bi.compare(token_amount, min_token_amount) >= 0,
            "Exchange less than min_token_amount!")

    -- 扣除COCOS，打入TOKEN
    if contract_base_info.caller ~= contract_base_info.owner then
        chainhelper:transfer_from_caller(contract_base_info.owner,
                cocos_amount, COCOS_ID, true)
        chainhelper:transfer_from_owner(contract_base_info.caller,
                token_amount, token_id, true)
    end

    pair_info.cocos_amount = tonumber(new_cocos_amount)
    pair_info.token_amount = tonumber(new_token_amount)
    for user_id, info in pairs(pair_info.liquidity_set) do
        local fee = bi.div(bi.mul(cocos_fee, info.p), pair_info.liquidity_total_p)
        info.cocos_fee = info.cocos_fee + tonumber(fee)
    end

    write_list = {
        public_data = {
            pair_set = true,
        }
    }
    chainhelper:write_chain()
end

-- public cocos兑换token以token为定值
function cocos2TokenConstToken(token_id, token_amount, max_cocos_amount)
    assert(type(token_id) == "string", "token_id should be string")
    assert(string.sub(token_id, 1, 4) == "1.3.", "token_id should be started with 1.3.")

    assert(isInteger(token_amount), "token_amount should be integer!")
    token_amount = tonumber(token_amount)
    assert(token_amount > 0 and token_amount <= TOKEN_AMOUNT_MAX,
            "token_amount should be in (0, " .. TOKEN_AMOUNT_MAX .. "]")

    assert(isInteger(max_cocos_amount), "max_cocos_amount should be integer!")
    max_cocos_amount = tonumber(max_cocos_amount)
    assert(max_cocos_amount >= 0 and max_cocos_amount <= TOKEN_AMOUNT_MAX,
            "max_cocos_amount should be in [0, " .. TOKEN_AMOUNT_MAX .. "]")

    read_list = {
        public_data = {
            pair_set = true,
        }
    }
    chainhelper:read_chain()

    local pair_info = public_data.pair_set[token_id]
    assert(pair_info, token_id .. " not found!")

    assert(pair_info.token_amount > token_amount, "not enough token to swap")

    local bi = import_contract(CONTRACT_BIGINTEGER)

    local new_cocos_amount, new_token_amount, cocos_amount, cocos_fee =
    tokenForExactToken(bi, pair_info.constant_k, pair_info.cocos_amount,
            pair_info.token_amount, token_amount)
    assert(bi.compare(new_cocos_amount, pair_info.cocos_amount) > 0,
            "Too little to exchange for " .. token_id)
    assert(bi.compare(new_cocos_amount, TOKEN_AMOUNT_MAX) <= 0,
            "Token amount greater than " .. TOKEN_AMOUNT_MAX)
    if max_cocos_amount > 0 then
        assert(bi.compare(cocos_amount, max_cocos_amount) <= 0,
                "Pay more than max_cocos_amount!")
    end

    -- 扣除COCOS，打入TOKEN
    if contract_base_info.caller ~= contract_base_info.owner then
        chainhelper:transfer_from_caller(contract_base_info.owner,
                cocos_amount, COCOS_ID, true)
        chainhelper:transfer_from_owner(contract_base_info.caller,
                token_amount, token_id, true)
    end

    pair_info.cocos_amount = tonumber(new_cocos_amount)
    pair_info.token_amount = tonumber(new_token_amount)
    for user_id, info in pairs(pair_info.liquidity_set) do
        local fee = bi.div(bi.mul(cocos_fee, info.p), pair_info.liquidity_total_p)
        info.cocos_fee = info.cocos_fee + tonumber(fee)
    end

    write_list = {
        public_data = {
            pair_set = true,
        }
    }
    chainhelper:write_chain()
end

-- public token兑换cocos以token为定值
function token2CocosConstToken(token_id, token_amount, min_cocos_amount)
    assert(type(token_id) == "string", "token_id should be string")
    assert(string.sub(token_id, 1, 4) == "1.3.", "token_id should be started with 1.3.")

    assert(isInteger(token_amount), "token_amount should be integer!")
    token_amount = tonumber(token_amount)
    assert(token_amount > 0 and token_amount <= TOKEN_AMOUNT_MAX,
            "token_amount should be in (0, " .. TOKEN_AMOUNT_MAX .. "]")

    assert(isInteger(min_cocos_amount), "min_cocos_amount should be integer!")
    min_cocos_amount = tonumber(min_cocos_amount)
    assert(min_cocos_amount >= 0 and min_cocos_amount <= TOKEN_AMOUNT_MAX,
            "min_cocos_amount should be in [0, " .. TOKEN_AMOUNT_MAX .. "]")

    read_list = {
        public_data = {
            pair_set = true,
        }
    }
    chainhelper:read_chain()

    local pair_info = public_data.pair_set[token_id]
    assert(pair_info, token_id .. " not found!")

    local bi = import_contract(CONTRACT_BIGINTEGER)

    local new_token_amount, new_cocos_amount, cocos_amount, token_fee =
    exactTokenForToken(bi, pair_info.constant_k, pair_info.token_amount,
            pair_info.cocos_amount, token_amount)
    assert(bi.compare(new_token_amount, TOKEN_AMOUNT_MAX) <= 0,
            "Token amount greater than " .. TOKEN_AMOUNT_MAX)
    assert(bi.compare(new_cocos_amount, pair_info.cocos_amount) < 0,
            "Too little to exchange for COCOS")
    assert(bi.compare(cocos_amount, min_cocos_amount) >= 0,
            "Exchange less than min_cocos_amount!")

    -- 扣除TOKEN，打入COCOS
    if contract_base_info.caller ~= contract_base_info.owner then
        chainhelper:transfer_from_caller(contract_base_info.owner,
                token_amount, token_id, true)
        chainhelper:transfer_from_owner(contract_base_info.caller,
                cocos_amount, COCOS_ID, true)
    end

    pair_info.token_amount = tonumber(new_token_amount)
    pair_info.cocos_amount = tonumber(new_cocos_amount)
    for user_id, info in pairs(pair_info.liquidity_set) do
        local fee = bi.div(bi.mul(token_fee, info.p), pair_info.liquidity_total_p)
        info.token_fee = info.token_fee + tonumber(fee)
    end

    write_list = {
        public_data = {
            pair_set = true,
        }
    }
    chainhelper:write_chain()
end

-- public token兑换cocos以cocos为定值
function token2CocosConstCocos(token_id, cocos_amount, max_token_amount)
    assert(type(token_id) == "string", "token_id should be string")
    assert(string.sub(token_id, 1, 4) == "1.3.", "token_id should be started with 1.3.")

    assert(isInteger(cocos_amount), "cocos_amount should be integer!")
    cocos_amount = tonumber(cocos_amount)
    assert(cocos_amount > 0 and cocos_amount <= TOKEN_AMOUNT_MAX,
            "cocos_amount should be in (0, " .. TOKEN_AMOUNT_MAX .. "]")

    assert(isInteger(max_token_amount), "max_token_amount should be integer!")
    max_token_amount = tonumber(max_token_amount)
    assert(max_token_amount >= 0 and max_token_amount <= TOKEN_AMOUNT_MAX,
            "max_token_amount should be in [0, " .. TOKEN_AMOUNT_MAX .. "]")

    read_list = {
        public_data = {
            pair_set = true,
        }
    }
    chainhelper:read_chain()

    local pair_info = public_data.pair_set[token_id]
    assert(pair_info, token_id .. " not found!")

    assert(pair_info.cocos_amount > cocos_amount, "not enough cocos to swap")

    local bi = import_contract(CONTRACT_BIGINTEGER)

    local new_token_amount, new_cocos_amount, token_amount, token_fee =
    tokenForExactToken(bi, pair_info.constant_k, pair_info.token_amount,
            pair_info.cocos_amount, cocos_amount)
    assert(bi.compare(new_token_amount, pair_info.token_amount) > 0,
            "Too little to exchange for COCOS")
    assert(bi.compare(new_token_amount, TOKEN_AMOUNT_MAX) <= 0,
            "Token amount greater than " .. TOKEN_AMOUNT_MAX)

    if max_token_amount > 0 then
        assert(bi.compare(token_amount, max_token_amount) <= 0,
                "Pay more than max_token_amount!")
    end

    -- 扣除TOKEN，打入COCOS
    if contract_base_info.caller ~= contract_base_info.owner then
        chainhelper:transfer_from_caller(contract_base_info.owner,
                token_amount, token_id, true)
        chainhelper:transfer_from_owner(contract_base_info.caller,
                cocos_amount, COCOS_ID, true)
    end

    pair_info.token_amount = tonumber(new_token_amount)
    pair_info.cocos_amount = tonumber(new_cocos_amount)
    for user_id, info in pairs(pair_info.liquidity_set) do
        local fee = bi.div(bi.mul(token_fee, info.p), pair_info.liquidity_total_p)
        info.token_fee = info.token_fee + tonumber(fee)
    end

    write_list = {
        public_data = {
            pair_set = true,
        }
    }
    chainhelper:write_chain()
end

-- public 首次注入流动性
function addLiquidityFirst(token_id, cocos_amount, token_amount)
    assert(type(token_id) == "string", "token_id should be string")
    assert(string.sub(token_id, 1, 4) == "1.3.", "token_id should be started with 1.3.")
    assert(token_id ~= COCOS_ID, "Token can not be COCOS")

    assert(isInteger(cocos_amount), "cocos_amount should be integer!")
    cocos_amount = tonumber(cocos_amount)
    assert(cocos_amount > 0 and cocos_amount <= TOKEN_AMOUNT_MAX,
            "cocos_amount should be in (0, " .. TOKEN_AMOUNT_MAX .. "]")

    assert(isInteger(token_amount), "token_amount should be integer!")
    token_amount = tonumber(token_amount)
    assert(token_amount > 0 and token_amount <= TOKEN_AMOUNT_MAX,
            "token_amount should be in (0, " .. TOKEN_AMOUNT_MAX .. "]")

    read_list = {
        public_data = {
            pair_set = true,
        }
    }
    chainhelper:read_chain()

    assert(not public_data.pair_set[token_id], "pair_info exist!")

    -- 扣除COCOS和TOKEN
    if contract_base_info.caller ~= contract_base_info.owner then
        chainhelper:transfer_from_caller(contract_base_info.owner,
                cocos_amount, COCOS_ID, true)
        chainhelper:transfer_from_caller(contract_base_info.owner,
                token_amount, token_id, true)
    end

    local bi = import_contract(CONTRACT_BIGINTEGER)

    local pair_info = {}
    pair_info.cocos_amount = cocos_amount
    pair_info.token_amount = token_amount
    pair_info.constant_k = bi.mul(cocos_amount, token_amount)
    pair_info.liquidity_total_p = P_DENO
    pair_info.liquidity_set = {}
    pair_info.liquidity_set[contract_base_info.caller] = {
        p = P_DENO,
        cocos_fee = 0,
        token_fee = 0,
    }

    public_data.pair_set[token_id] = pair_info

    write_list = {
        public_data = {
            pair_set = true,
        }
    }
    chainhelper:write_chain()
end

-- public 注入流动性
function addLiquidity(token_id, cocos_amount, token_amount, min_cocos_amount, min_token_amount)
    assert(type(token_id) == "string", "token_id should be string")
    assert(string.sub(token_id, 1, 4) == "1.3.", "token_id should be started with 1.3.")

    assert(isInteger(cocos_amount), "cocos_amount should be integer!")
    cocos_amount = tonumber(cocos_amount)
    assert(cocos_amount >= 0 and cocos_amount <= TOKEN_AMOUNT_MAX,
            "cocos_amount should be in [0, " .. TOKEN_AMOUNT_MAX .. "]")

    assert(isInteger(token_amount), "token_amount should be integer!")
    token_amount = tonumber(token_amount)
    assert(token_amount >= 0 and token_amount <= TOKEN_AMOUNT_MAX,
            "token_amount should be in [0, " .. TOKEN_AMOUNT_MAX .. "]")

    assert(cocos_amount > 0 or token_amount > 0,
            "Either cocos_amount or token_amount should > 0!")

    assert(isInteger(min_cocos_amount), "min_cocos_amount should be integer!")
    min_cocos_amount = tonumber(min_cocos_amount)
    assert(min_cocos_amount >= 0 and min_cocos_amount <= TOKEN_AMOUNT_MAX,
            "min_cocos_amount should be in [0, " .. TOKEN_AMOUNT_MAX .. "]")

    assert(isInteger(min_token_amount), "min_token_amount should be integer!")
    min_token_amount = tonumber(min_token_amount)
    assert(min_token_amount >= 0 and min_token_amount <= TOKEN_AMOUNT_MAX,
            "min_token_amount should be in [0, " .. TOKEN_AMOUNT_MAX .. "]")

    read_list = {
        public_data = {
            pair_set = true,
        }
    }
    chainhelper:read_chain()

    local pair_info = public_data.pair_set[token_id]
    assert(pair_info, "pair_info not found!")

    local bi = import_contract(CONTRACT_BIGINTEGER)

    if cocos_amount == 0 then
        cocos_amount = bi.div(bi.mul(pair_info.cocos_amount, token_amount), pair_info.token_amount)
    elseif token_amount == 0 then
        token_amount = bi.div(bi.mul(pair_info.token_amount, cocos_amount),pair_info.cocos_amount)
    elseif bi.compare(bi.mul(cocos_amount, pair_info.token_amount),
            bi.mul(pair_info.cocos_amount, token_amount)) > 0 then

        cocos_amount = bi.div(bi.mul(pair_info.cocos_amount, token_amount), pair_info.token_amount)
    else
        token_amount = bi.div(bi.mul(pair_info.token_amount, cocos_amount), pair_info.cocos_amount)
    end

    local new_cocos_amount = bi.add(pair_info.cocos_amount, cocos_amount)
    local new_token_amount = bi.add(pair_info.token_amount, token_amount)
    assert(bi.compare(new_cocos_amount, TOKEN_AMOUNT_MAX) <= 0,
            "Token amount greater than " .. TOKEN_AMOUNT_MAX)
    assert(bi.compare(new_token_amount, TOKEN_AMOUNT_MAX) <= 0,
            "Token amount greater than " .. TOKEN_AMOUNT_MAX)

    cocos_amount = tonumber(cocos_amount)
    token_amount = tonumber(token_amount)
    new_cocos_amount = tonumber(new_cocos_amount)
    new_token_amount = tonumber(new_token_amount)

    assert(cocos_amount >= min_cocos_amount,
            "Pay cocos_amount should be >= min_cocos_amount!")
    assert(token_amount >= min_token_amount,
            "Pay token_amount should be >= min_token_amount!")

    -- 扣除COCOS和TOKEN
    if contract_base_info.caller ~= contract_base_info.owner then
        chainhelper:transfer_from_caller(contract_base_info.owner,
                cocos_amount, COCOS_ID, true)
        chainhelper:transfer_from_caller(contract_base_info.owner,
                token_amount, token_id, true)
    end

    pair_info.liquidity_set[contract_base_info.caller] =
    pair_info.liquidity_set[contract_base_info.caller] or {
        p = P_DENO,
        cocos_fee = 0,
        token_fee = 0,
    }

    local new_total_p = 0
    for user_id, info in pairs(pair_info.liquidity_set) do
        if user_id == contract_base_info.caller then
            local p0 = bi.div(bi.add(bi.mul(pair_info.cocos_amount, info.p), bi.mul(cocos_amount, P_DENO)), new_cocos_amount)
            local p1 = bi.div(bi.add(bi.mul(pair_info.token_amount, info.p), bi.mul(token_amount, P_DENO)), new_token_amount)

            info.p = math.min(tonumber(p0), tonumber(p1))
        else
            info.p = tonumber(bi.div(bi.mul(pair_info.cocos_amount, info.p), new_cocos_amount))
        end

        new_total_p = new_total_p + info.p
    end

    pair_info.liquidity_total_p = new_total_p -- 考虑由于精度损失造成的占比总和略小于1的情况
    pair_info.cocos_amount = new_cocos_amount
    pair_info.token_amount = new_token_amount
    pair_info.constant_k = bi.mul(pair_info.cocos_amount, pair_info.token_amount)

    write_list = {
        public_data = {
            pair_set = true,
        }
    }
    chainhelper:write_chain()
end

-- public 赎回流动性
function removeLiquidity(token_id, proportion)
    assert(type(token_id) == "string", "token_id should be string")
    assert(string.sub(token_id, 1, 4) == "1.3.", "token_id should be started with 1.3.")

    assert(isInteger(proportion), "proportion should be integer!")
    proportion = tonumber(proportion)
    assert(proportion > 0 and proportion <= P_DENO,
            "proportion should be in (0, " .. P_DENO .. "]")

    read_list = {
        public_data = {
            pair_set = true,
        }
    }
    chainhelper:read_chain()

    local pair_info = public_data.pair_set[token_id]
    assert(pair_info, "pair_info not found!")

    local bi = import_contract(CONTRACT_BIGINTEGER)

    assert(pair_info.liquidity_set[contract_base_info.caller], "No liquidity to remove!")
    local old_p = pair_info.liquidity_set[contract_base_info.caller].p

    local pp = bi.mul(old_p, proportion)
    local p_square = bi.mul(P_DENO, P_DENO)
    local cocos_amount = tonumber(bi.div(bi.mul(pair_info.cocos_amount, pp), p_square))
    local token_amount = tonumber(bi.div(bi.mul(pair_info.token_amount, pp), p_square))

    local cocos_fee = tonumber(bi.div(bi.mul(pair_info.liquidity_set[contract_base_info.caller].cocos_fee, proportion), P_DENO))
    local token_fee = tonumber(bi.div(bi.mul(pair_info.liquidity_set[contract_base_info.caller].token_fee, proportion), P_DENO))

    -- 打入COCOS和TOKEN
    if contract_base_info.caller ~= contract_base_info.owner then
        chainhelper:transfer_from_owner(contract_base_info.caller,
                cocos_amount, COCOS_ID, true)
        chainhelper:transfer_from_owner(contract_base_info.caller,
                token_amount, token_id, true)
        chainhelper:transfer_from_owner(contract_base_info.caller,
                cocos_fee, COCOS_ID, true)
        chainhelper:transfer_from_owner(contract_base_info.caller,
                token_fee, token_id, true)
    end

    if pair_info.cocos_amount <= cocos_amount or pair_info.token_amount <= token_amount then
        public_data.pair_set[token_id] = nil -- 全部流动性被撤出
    else
        local new_cocos_amount = pair_info.cocos_amount - cocos_amount
        local new_token_amount = pair_info.token_amount - token_amount

        local new_total_p = 0
        for user_id, info in pairs(pair_info.liquidity_set) do
            if user_id == contract_base_info.caller then
                if proportion < P_DENO then
                    local p0 = bi.div(bi.sub(bi.mul(pair_info.cocos_amount, info.p), bi.mul(cocos_amount, P_DENO)), new_cocos_amount)
                    local p1 = bi.div(bi.sub(bi.mul(pair_info.token_amount, info.p), bi.mul(token_amount, P_DENO)), new_token_amount)
                    info.p = math.min(tonumber(p0), tonumber(p1))

                    info.cocos_fee = info.cocos_fee - cocos_fee
                    info.token_fee = info.token_fee - token_fee
                else
                    info.p = 0
                    pair_info.liquidity_set[user_id] = nil
                end
            else
                info.p = bi.div(bi.mul(pair_info.cocos_amount, info.p), new_cocos_amount)
                info.cocos_fee = info.cocos_fee - cocos_fee
                info.token_fee = info.token_fee - token_fee
            end

            new_total_p = new_total_p + info.p
        end

        pair_info.liquidity_total_p = new_total_p -- 考虑由于精度损失造成的占比总和略小于1的情况
        pair_info.cocos_amount = new_cocos_amount
        pair_info.token_amount = new_token_amount
        pair_info.constant_k = bi.mul(new_cocos_amount, new_token_amount)
    end

    write_list = {
        public_data = {
            pair_set = true,
        }
    }
    chainhelper:write_chain()
end