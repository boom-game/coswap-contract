-- 管理员账号
local ADMIN_ACCOUNTS = {"1.2.1252660", "1.2.70"}

-- 管理员锁定用的代币
local LOCK_TOKEN = "COCOS"

-- 主币
local COCOS_SYMBOL = "COCOS"

-- 能支持的代币最大数值
local TOKEN_AMOUNT_MAX = 1000000000000000000

-- 创建交易对时，预留的流动性数量
local LIQUIDITY_MIN = 1000

local FEE_DENO = 10000          -- 费率分母
local FEE_EXCHANGE_NUME = 30    -- 兑换费率
local FEE_PLATFORM_NUME = 5     -- 平台费率，包含在兑换费率里

local CONTRACT_BIGINTEGER = "contract.crosbiginteger" -- 大整数计算库
local CONTRACT_ASSET = "contract.crosasset" -- 资产管理合约

-- nft
local NFT_WORLDVIEW = "CROSWAP" -- 世界观

local NFT_TYPE_PAIR = "swap pair" -- 代表一个交易对
local NFT_TYPE_LP = "swap lp" -- 代表一个流动性凭证

local PAIR_ICON = "http://www.croswap.com/pair_icon.png" -- 交易对图标

local LP_VERSION = 1 -- 凭证版本
local LP_ICON = "http://www.croswap.com/swap_token.png" -- 凭证图标

-- 销毁nft用的空账号
local ACCOUNT_NULL = "null-account"


-- 检查token_symbol
local function _checkTokenSymbol(token_symbol)
    assert(type(token_symbol) == "string", "token_symbol should be string")
    assert(string.sub(token_symbol, 1, 4) ~= "1.3.",
            "token_symbol should not starts with 1.3.")
end

-- 检查代币数量，number或者string，范围[min, max]的整数
local function _checkTokenAmount(amount, min, max)
    assert(type(amount) == "number" or type(amount) == "string",
            "invalid type of amount")
    amount = tonumber(amount)
    assert(amount and math.floor(amount) == amount,
            "amount should be integer")

    if min then
        assert(amount >= min, "too little amount")
    end

    if max then
        assert(amount <= max, "too much amount")
    end

    return amount
end

-- 检查是否管理员
local function _checkAdmin(account_id)
    local found = false

    for i, ai in pairs(ADMIN_ACCOUNTS) do
        if ai == account_id then
            found = true
            break
        end
    end

    assert(found, "you are not admin")
end

-- 正整数开方
local function _sqrt(bi, x)
    if bi.compare(x, 3) <= 0 then
        return "1"
    end

    local r = x
    local t = bi.add(bi.div(x, 2), 1)

    while bi.compare(t, r) < 0 do
        r = t
        t = bi.div(bi.add(bi.div(x, t), t), 2)
    end

    return r
end

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

-- 转入代币
local function _transferIn(token_symbol, amount)
    _invokeContractFunction(CONTRACT_ASSET, "transferIn", token_symbol, amount)
end

-- 转出代币
local function _transferOut(token_symbol, amount)
    _invokeContractFunction(CONTRACT_ASSET, "transferOut", token_symbol, amount)
end

-- 固定的a兑换b
local function _exactTokenForToken(bi, amount0, amount1, delta0, fee_nume)
    -- 向上取整，(m + m - 1) / n
    local fee = bi.div(bi.add(bi.mul(delta0, fee_nume), FEE_DENO - 1), FEE_DENO)

    local new_amount0 = bi.add(amount0, delta0)
    local new_amount0_fee = bi.sub(new_amount0, fee)		-- new_amount0 - fee
    local new_amount0_fee_1 = bi.sub(new_amount0_fee, 1)	-- new_amount0 - fee - 1

    -- 向上取整，(m + m - 1) / n
    local new_amount1 = bi.div(bi.add(bi.mul(amount0, amount1), new_amount0_fee_1), new_amount0_fee)
    local delta1 = bi.sub(amount1, new_amount1)

    return new_amount0, new_amount1, delta1
end

-- a兑换固定的b
local function _tokenForExactToken(bi, amount0, amount1, delta1, fee_nume)
    local new_amount1 = bi.sub(amount1, delta1)
    local new_amount1_1 = bi.sub(new_amount1, 1) -- new_amount1 - 1
    -- 向上取整，(m + m - 1) / n
    local new_amount0 = bi.div(bi.add(bi.mul(amount0, amount1), new_amount1_1), new_amount1)

    local delta0 = bi.sub(new_amount0, amount0)
    -- 向上取整，(m + m - 1) / n
    local fee = bi.div(bi.add(bi.mul(delta0, fee_nume), FEE_DENO - fee_nume - 1),
            FEE_DENO - fee_nume)
    delta0 = bi.add(delta0, fee)
    new_amount0 = bi.add(new_amount0, fee)

    return new_amount0, new_amount1, delta0
end

-- 记录平台交易费
local function _addPlatformFee(platform_fee)
    read_list = {
        public_data = {
            platform_fee = true,
        },
    }
    chainhelper:read_chain()

    public_data.platform_fee = public_data.platform_fee + platform_fee

    write_list = {
        public_data = {
            platform_fee = true,
        },
    }
    chainhelper:write_chain()
end

-------------------- 交易对 --------------------

-- 写入交易对数据
local function _writePair(pair_id, cocos_amount, token_amount, liquidity)
    if contract_base_info.caller ~= contract_base_info.owner then
        chainhelper:change_nht_active_by_owner(
                contract_base_info.caller, pair_id, true)
    end

    local value = cjson.encode({
        c = cocos_amount,
        t = token_amount,
        l = liquidity,
    })

    chainhelper:nht_describe_change(pair_id, "pair", value, true)

    if contract_base_info.caller ~= contract_base_info.owner then
        chainhelper:change_nht_active_by_owner(
                contract_base_info.owner, pair_id, true)
    end
end

-- 创建交易对
local function _createPair(token_symbol, cocos_amount, token_amount, liquidity)
    local describe = {
        type = NFT_TYPE_PAIR,
        name = "COCOS-" .. token_symbol .. "-PAIR",
        icon = PAIR_ICON,
        token_symbol = token_symbol,
    }

    local pair_id = chainhelper:create_nft_asset(contract_base_info.owner,
            NFT_WORLDVIEW, cjson.encode(describe), true, true)

    _writePair(pair_id, cocos_amount, token_amount, liquidity)

    _invokeContractFunction(CONTRACT_ASSET, "lockNFT", pair_id)

    public_data = {
        pairs = {
            [token_symbol] = pair_id,
        },
    }

    write_list = {
        public_data = {
            pairs = {
                [token_symbol] = true,
            },
        },
    }
    chainhelper:write_chain()

    return pair_id
end

-- 读取交易对数据
local function _readPair(token_symbol, exist)
    read_list = {
        public_data = {
            pairs = {
                [token_symbol] = true,
            },
        },
    }
    chainhelper:read_chain()

    if not public_data.pairs or not public_data.pairs[token_symbol] then
        if exist then
            assert(false, "pair not exist")
        else
            return nil
        end
    end

    if not exist then
        assert(false, "pair existed")
    end

    local pair_id = public_data.pairs[token_symbol]
    local pair = cjson.decode(chainhelper:get_nft_asset(pair_id))

    local data = nil

    for _, contract in pairs(pair.describe_with_contract) do
        if contract[1] == contract_base_info.id then
            for _, describe in pairs(contract[2]) do
                if describe[1] == "pair" then
                    data = cjson.decode(describe[2])
                    break
                end
            end

            break
        end
    end

    return data, pair_id
end

-------------------- 凭证 --------------------

-- 创建凭证，并转给caller
local function _createLP(token_symbol, liquidity)
    local describe = {
        type = NFT_TYPE_LP,
        name = "COCOS-" .. token_symbol .. "-LP",
        icon = LP_ICON,
        version = LP_VERSION,
        token_symbol = token_symbol,
        liquidity = liquidity,
    }

    local lp_id = chainhelper:create_nft_asset(contract_base_info.owner,
            NFT_WORLDVIEW, cjson.encode(describe), true, true)

    if contract_base_info.caller ~= contract_base_info.owner then
        chainhelper:transfer_nht_from_owner(contract_base_info.caller, lp_id, true)
    end

    return lp_id
end

-- 检查凭证，返回describe
function checkLP(lp_id)
    assert(type(lp_id) == "string", "lp_id should be string")
    assert(string.sub(lp_id, 1, 4) == "4.2.",
            "lp_id should starts with 4.2.")

    local lp = cjson.decode(chainhelper:get_nft_asset(lp_id))
    assert(lp, "lp not found")

    assert(lp.world_view == NFT_WORLDVIEW, "invalid lp worldview")

    assert(lp.nh_asset_creator == contract_base_info.owner,
            "invalid lp creator")
    assert(lp.nh_asset_owner == contract_base_info.caller,
            "you do not have ownership")
    assert(lp.nh_asset_active == contract_base_info.caller,
            "you do not have active")
    assert(lp.dealership == contract_base_info.caller,
            "you do not have dealership")

    local describe = cjson.decode(lp.base_describe)
    assert(describe.type == NFT_TYPE_LP and describe.version == LP_VERSION,
            "invalid lp describe")

    return describe
end

-- 销毁凭证
local function _destroyLP(lp_id, reason, target_id)
    chainhelper:nht_describe_change(lp_id, "destroy_reason", reason, true)
    if type(target_id) == "string" then
        chainhelper:nht_describe_change(lp_id, "target_id", target_id, true)
    elseif type(target_id) == "table" then
        chainhelper:nht_describe_change(lp_id, "target_ids", cjson.encode(target_id), true)
    end

    chainhelper:transfer_nht_from_caller(ACCOUNT_NULL, lp_id, true)
end

-- 初始化
function init()
    assert(contract_base_info.invoker_contract_id == "1.16.0",
            "can not be called by other contracts")
    assert(chainhelper:is_owner(), "owner only")

    read_list = {
        public_data = {},
    }
    chainhelper:read_chain()

    -- 平台交易费记录
    public_data.platform_fee = public_data.platform_fee or 0

    -- 所有交易对id
    public_data.pairs = public_data.pairs or {}

    -- 管理员锁定记录
    public_data.admin_lock = public_data.admin_lock or {}

    write_list = {
        public_data = {},
    }
    chainhelper:write_chain()
end

-- 创建交易对
function createPair(token_symbol, cocos_amount, token_amount)
    _checkTokenSymbol(token_symbol)
    assert(token_symbol ~= COCOS_SYMBOL, "token can not be " .. COCOS_SYMBOL)

    cocos_amount = _checkTokenAmount(cocos_amount, 1, TOKEN_AMOUNT_MAX)
    token_amount = _checkTokenAmount(token_amount, 1, TOKEN_AMOUNT_MAX)

    _readPair(token_symbol, false)

    local bi = import_contract(CONTRACT_BIGINTEGER)

    local liquidity = tonumber(_sqrt(bi, bi.mul(cocos_amount, token_amount)))
    assert(liquidity > LIQUIDITY_MIN, "too little token")

    _transferIn(COCOS_SYMBOL, cocos_amount)
    _transferIn(token_symbol, token_amount)

    local pair_id = _createPair(token_symbol, cocos_amount, token_amount, liquidity)
    _createLP(token_symbol, liquidity - LIQUIDITY_MIN)

    local log = {
        text = string.format("%s创建了%s-%s交易对，用%d %s和%d %s得到%d流动性",
                contract_base_info.caller, COCOS_SYMBOL, token_symbol,
                cocos_amount, COCOS_SYMBOL,
                token_amount, token_symbol,
                liquidity - LIQUIDITY_MIN),
        token_symbol = token_symbol,
        cocos_amount = cocos_amount,
        token_amount = token_amount,
        platform_fee = 0,
        pair_id = pair_id,
        cocos_balance = cocos_amount,
        token_balance = token_amount,
        liquidity_balance = liquidity,
    }
    chainhelper:log(cjson.encode(log))
end

-- 增加流动性
function addLiquidity(token_symbol, cocos_amount, token_amount,
                      cocos_min, token_min, lp_ids)

    _checkTokenSymbol(token_symbol)

    cocos_amount = _checkTokenAmount(cocos_amount, 1, TOKEN_AMOUNT_MAX)
    token_amount = _checkTokenAmount(token_amount, 1, TOKEN_AMOUNT_MAX)
    cocos_min = _checkTokenAmount(cocos_min, 0, TOKEN_AMOUNT_MAX)
    token_min = _checkTokenAmount(token_min, 0, TOKEN_AMOUNT_MAX)

    assert(type(lp_ids) == "string", "invalid type of lp_ids")
    lp_ids = cjson.decode(lp_ids)
    assert(type(lp_ids) == "table", "invalid type of lp_ids")

    local liqOld = 0
    local lp_map = {}

    for i, lp_id in pairs(lp_ids) do
        assert(not lp_map[lp_id], "duplicate lp")
        lp_map[lp_id] = true

        local lp = checkLP(lp_id)

        assert(lp.token_symbol == token_symbol, "token_symbol not match")

        liqOld = liqOld + lp.liquidity
    end

    local pair, pair_id = _readPair(token_symbol, true)

    local bi = import_contract(CONTRACT_BIGINTEGER)

    local m0 = bi.mul(cocos_amount, pair.t)
    local m1 = bi.mul(token_amount, pair.c)

    if bi.compare(m0, m1) <= 0 then
        token_amount = tonumber(bi.div(m0, pair.c))
    else
        cocos_amount = tonumber(bi.div(m1, pair.t))
    end

    assert(cocos_amount >= cocos_min, "COCOS amount < min")
    assert(token_amount >= token_min, "token amount < min")

    _transferIn(COCOS_SYMBOL, cocos_amount)
    _transferIn(token_symbol, token_amount)

    local liqNew = tonumber(bi.div(bi.mul(cocos_amount, pair.l), pair.c))
    assert(liqNew > 0, "too little amount")

    local target_id = _createLP(token_symbol, liqOld + liqNew)

    for i, lp_id in pairs(lp_ids) do
        _destroyLP(lp_id, "merge lp", target_id);
    end

    _writePair(pair_id, pair.c + cocos_amount, pair.t + token_amount,
            pair.l + liqNew)

    local log = {
        text = string.format("%s添加%s-%s流动性，用%d %s和%d %s得到%d流动性",
                contract_base_info.caller, COCOS_SYMBOL, token_symbol,
                cocos_amount, COCOS_SYMBOL,
                token_amount, token_symbol,
                liqNew),
        token_symbol = token_symbol,
        cocos_amount = cocos_amount,
        token_amount = token_amount,
        platform_fee = 0,
        pair_id = pair_id,
        cocos_balance = pair.c + cocos_amount,
        token_balance = pair.t + token_amount,
        liquidity_balance = pair.l + liqNew,
    }
    chainhelper:log(cjson.encode(log))
end

-- 赎回流动性
function removeLiquidity(lp_id, liq, cocos_min, token_min)
    local lp = checkLP(lp_id)
    local token_symbol = lp.token_symbol
    local liquidity = lp.liquidity

    liq = _checkTokenAmount(liq, 1, liquidity)

    cocos_min = _checkTokenAmount(cocos_min, 0, TOKEN_AMOUNT_MAX)
    token_min = _checkTokenAmount(token_min, 0, TOKEN_AMOUNT_MAX)

    local pair, pair_id = _readPair(token_symbol, true)

    local bi = import_contract(CONTRACT_BIGINTEGER)

    local cocos_amount = tonumber(bi.div(bi.mul(pair.c, liq), pair.l))
    local token_amount = tonumber(bi.div(bi.mul(pair.t, liq), pair.l))

    assert(cocos_amount >= cocos_min, "COCOS amount < min")
    assert(token_amount >= token_min, "token amount < min")

    _transferOut(COCOS_SYMBOL, cocos_amount)
    _transferOut(token_symbol, token_amount)

    if liquidity > liq then
        local target_id = _createLP(token_symbol, liquidity - liq)
        _destroyLP(lp_id, "remove liquidity partial", target_id)
    else
        _destroyLP(lp_id, "remove liquidity")
    end

    _writePair(pair_id, pair.c - cocos_amount, pair.t - token_amount,
            pair.l - liq)

    local log = {
        text = string.format("%s赎回%s-%s流动性，用%d流动性得到%d %s和%d %s",
                contract_base_info.caller, COCOS_SYMBOL, token_symbol,
                liq,
                cocos_amount, COCOS_SYMBOL,
                token_amount, token_symbol),
        token_symbol = token_symbol,
        cocos_amount = -cocos_amount,
        token_amount = -token_amount,
        platform_fee = 0,
        pair_id = pair_id,
        cocos_balance = pair.c - cocos_amount,
        token_balance = pair.t - token_amount,
        liquidity_balance = pair.l - liq,
    }
    chainhelper:log(cjson.encode(log))
end

-- 固定的COCOS兑换token
function exactCocosForToken(token_symbol, cocos_amount, token_min)
    _checkTokenSymbol(token_symbol)

    cocos_amount = _checkTokenAmount(cocos_amount, 1, TOKEN_AMOUNT_MAX)
    token_min = _checkTokenAmount(token_min, 1, TOKEN_AMOUNT_MAX)

    local pair, pair_id = _readPair(token_symbol, true)

    local bi = import_contract(CONTRACT_BIGINTEGER)

    assert(bi.compare(bi.add(pair.c, cocos_amount), TOKEN_AMOUNT_MAX) <= 0,
            "too much amount")

    local new_cocos_amount, new_token_amount, token_amount =
    _exactTokenForToken(bi, pair.c, pair.t, cocos_amount, FEE_EXCHANGE_NUME)

    new_cocos_amount = tonumber(new_cocos_amount)
    new_token_amount = tonumber(new_token_amount)
    token_amount = tonumber(token_amount)

    assert(new_token_amount > 0, "at least 1 token left")
    assert(token_amount >= token_min, "token amount < min")

    _transferIn(COCOS_SYMBOL, cocos_amount)
    _transferOut(token_symbol, token_amount)

    local platform_fee = tonumber(bi.div(bi.mul(cocos_amount,
            FEE_PLATFORM_NUME), FEE_DENO))

    _writePair(pair_id, new_cocos_amount - platform_fee, new_token_amount, pair.l)

    _addPlatformFee(platform_fee)

    local log = {
        text = string.format("%s用%d %s兑换了%d %s",
                contract_base_info.caller,
                cocos_amount, COCOS_SYMBOL,
                token_amount, token_symbol),
        token_symbol = token_symbol,
        cocos_amount = cocos_amount,
        token_amount = -token_amount,
        platform_fee = platform_fee,
        pair_id = pair_id,
        cocos_balance = new_cocos_amount - platform_fee,
        token_balance = new_token_amount,
        liquidity_balance = pair.l,
    }
    chainhelper:log(cjson.encode(log))
end

-- COCOS兑换固定的token
function cocosForExactToken(token_symbol, token_amount, cocos_max)
    _checkTokenSymbol(token_symbol)

    token_amount = _checkTokenAmount(token_amount, 1, TOKEN_AMOUNT_MAX)
    cocos_max = _checkTokenAmount(cocos_max, 1, TOKEN_AMOUNT_MAX)

    local pair, pair_id = _readPair(token_symbol, true)

    assert(token_amount < pair.t, "not enough token to swap")

    local bi = import_contract(CONTRACT_BIGINTEGER)

    local new_cocos_amount, new_token_amount, cocos_amount =
    _tokenForExactToken(bi, pair.c, pair.t, token_amount, FEE_EXCHANGE_NUME)

    assert(bi.compare(new_cocos_amount, TOKEN_AMOUNT_MAX) <= 0,
            "too much amount")

    new_cocos_amount = tonumber(new_cocos_amount)
    new_token_amount = tonumber(new_token_amount)
    cocos_amount = tonumber(cocos_amount)

    assert(cocos_amount > 0, "too little amount")
    assert(cocos_amount <= cocos_max, "COCOS amount > max")

    _transferIn(COCOS_SYMBOL, cocos_amount)
    _transferOut(token_symbol, token_amount)

    local platform_fee = tonumber(bi.div(bi.mul(cocos_amount,
            FEE_PLATFORM_NUME), FEE_DENO))

    _writePair(pair_id, new_cocos_amount - platform_fee, new_token_amount, pair.l)

    _addPlatformFee(platform_fee)

    local log = {
        text = string.format("%s用%d %s兑换了%d %s",
                contract_base_info.caller,
                cocos_amount, COCOS_SYMBOL,
                token_amount, token_symbol),
        token_symbol = token_symbol,
        cocos_amount = cocos_amount,
        token_amount = -token_amount,
        platform_fee = platform_fee,
        pair_id = pair_id,
        cocos_balance = new_cocos_amount - platform_fee,
        token_balance = new_token_amount,
        liquidity_balance = pair.l,
    }
    chainhelper:log(cjson.encode(log))
end

-- 固定的token兑换COCOS
function exactTokenForCocos(token_symbol, token_amount, cocos_min)
    _checkTokenSymbol(token_symbol)

    token_amount = _checkTokenAmount(token_amount, 1, TOKEN_AMOUNT_MAX)
    cocos_min = _checkTokenAmount(cocos_min, 1, TOKEN_AMOUNT_MAX)

    local pair, pair_id = _readPair(token_symbol, true)

    local bi = import_contract(CONTRACT_BIGINTEGER)

    assert(bi.compare(bi.add(pair.t, token_amount), TOKEN_AMOUNT_MAX) <= 0,
            "too much amount")

    local new_token_amount, new_cocos_amount, cocos_amount =
    _exactTokenForToken(bi, pair.t, pair.c, token_amount, FEE_EXCHANGE_NUME)

    new_token_amount = tonumber(new_token_amount)
    new_cocos_amount = tonumber(new_cocos_amount)
    cocos_amount = tonumber(cocos_amount)

    assert(cocos_amount >= cocos_min, "COCOS amount < min")

    local nta, nca, ca = _exactTokenForToken(bi, pair.t, pair.c,
            token_amount, FEE_EXCHANGE_NUME - FEE_PLATFORM_NUME)
    nca = tonumber(nca)

    assert(nca > 0, "at least 1 token left")

    _transferIn(token_symbol, token_amount)
    _transferOut(COCOS_SYMBOL, cocos_amount)

    _writePair(pair_id, nca, new_token_amount, pair.l)

    _addPlatformFee(new_cocos_amount - nca)

    local log = {
        text = string.format("%s用%d %s兑换了%d %s",
                contract_base_info.caller,
                token_amount, token_symbol,
                cocos_amount, COCOS_SYMBOL),
        token_symbol = token_symbol,
        cocos_amount = -cocos_amount,
        token_amount = token_amount,
        platform_fee = new_cocos_amount - nca,
        pair_id = pair_id,
        cocos_balance = nca,
        token_balance = new_token_amount,
        liquidity_balance = pair.l,
    }
    chainhelper:log(cjson.encode(log))
end

-- token兑换固定的COCOS
function tokenForExactCocos(token_symbol, cocos_amount, token_max)
    _checkTokenSymbol(token_symbol)

    cocos_amount = _checkTokenAmount(cocos_amount, 1, TOKEN_AMOUNT_MAX)
    token_max = _checkTokenAmount(token_max, 1, TOKEN_AMOUNT_MAX)

    local pair, pair_id = _readPair(token_symbol, true)

    assert(cocos_amount < pair.c, "not enough COCOS to swap")

    local bi = import_contract(CONTRACT_BIGINTEGER)

    local new_token_amount, new_cocos_amount, token_amount =
    _tokenForExactToken(bi, pair.t, pair.c, cocos_amount, FEE_EXCHANGE_NUME)

    assert(bi.compare(new_token_amount, TOKEN_AMOUNT_MAX) <= 0,
            "too much amount")

    new_token_amount = tonumber(new_token_amount)
    new_cocos_amount = tonumber(new_cocos_amount)
    token_amount = tonumber(token_amount)

    assert(token_amount > 0, "too little amount")
    assert(token_amount <= token_max, "token amount > max")

    local nta, nca, ca = _exactTokenForToken(bi, pair.t, pair.c,
            token_amount, FEE_EXCHANGE_NUME - FEE_PLATFORM_NUME)
    nca = tonumber(nca)

    assert(nca > 0, "at least 1 token left")

    _transferIn(token_symbol, token_amount)
    _transferOut(COCOS_SYMBOL, cocos_amount)

    _writePair(pair_id, nca, new_token_amount, pair.l)

    _addPlatformFee(new_cocos_amount - nca)

    local log = {
        text = string.format("%s用%d %s兑换了%d %s",
                contract_base_info.caller,
                token_amount, token_symbol,
                cocos_amount, COCOS_SYMBOL),
        token_symbol = token_symbol,
        cocos_amount = -cocos_amount,
        token_amount = token_amount,
        platform_fee = new_cocos_amount - nca,
        pair_id = pair_id,
        cocos_balance = nca,
        token_balance = new_token_amount,
        liquidity_balance = pair.l,
    }
    chainhelper:log(cjson.encode(log))
end

-- 合并流动性凭证
function mergeLP(lp_ids)
    assert(type(lp_ids) == "string", "invalid type")
    lp_ids = cjson.decode(lp_ids)
    assert(type(lp_ids) == "table", "invalid type")
    assert(#lp_ids >= 2, "at least two")

    local lp_map = {}
    local liquidity = 0
    local token_symbol = nil

    for i, lp_id in pairs(lp_ids) do
        assert(not lp_map[lp_id], "duplicate lp")
        lp_map[lp_id] = true

        local lp = checkLP(lp_id)

        if not token_symbol then
            token_symbol = lp.token_symbol
        else
            assert(token_symbol == lp.token_symbol, "diffevent token_symbol")
        end

        liquidity = liquidity + lp.liquidity
    end

    local target_id = _createLP(token_symbol, liquidity)

    for i, lp_id in pairs(lp_ids) do
        _destroyLP(lp_id, "merge lp", target_id);
    end
end

-- 拆分流动性凭证
function splitLP(lp_id, liq1)
    local lp = checkLP(lp_id)
    local token_symbol = lp.token_symbol

    liq1 = _checkTokenAmount(liq1, 1, lp.liquidity - 1)
    local liq2 = lp.liquidity - liq1

    local target_id1 = _createLP(token_symbol, liq1)
    local target_id2 = _createLP(token_symbol, liq2)

    _destroyLP(lp_id, "split lp", {target_id1, target_id2})
end

-- 管理员锁定合约
function lockContract()
    assert(contract_base_info.invoker_contract_id == "1.16.0",
            "can not be called by other contracts")

    local account_id = contract_base_info.caller
    _checkAdmin(account_id)

    read_list = {
        public_data = {
            admin_lock = true,
        }
    }
    chainhelper:read_chain()

    assert(not public_data.admin_lock[account_id], "you has locked")
    public_data.admin_lock[account_id] = true

    local token_amount = 1
    if account_id ~= contract_base_info.owner then
        chainhelper:transfer_from_caller(contract_base_info.owner, token_amount, LOCK_TOKEN, true)
    end
    chainhelper:adjust_lock_asset(LOCK_TOKEN, token_amount)

    write_list = {
        public_data = {
            admin_lock = true,
        }
    }
    chainhelper:write_chain()
end

-- 管理员解锁合约
function unlockContract()
    assert(contract_base_info.invoker_contract_id == "1.16.0",
            "can not be called by other contracts")

    local account_id = contract_base_info.caller
    _checkAdmin(account_id)

    read_list = {
        public_data = {
            admin_lock = true,
        }
    }
    chainhelper:read_chain()

    assert(public_data.admin_lock[account_id], "you has unlocked")
    public_data.admin_lock[account_id] = false

    local token_amount = 1
    chainhelper:adjust_lock_asset(LOCK_TOKEN, -token_amount)
    if account_id ~= contract_base_info.owner then
        chainhelper:transfer_from_owner(account_id, token_amount, LOCK_TOKEN, true)
    end

    write_list = {
        public_data = {
            admin_lock = true,
        }
    }
    chainhelper:write_chain()
end

-- 提取手续费
function withdrawPlatformFee(amount, target_account)
    assert(contract_base_info.invoker_contract_id == "1.16.0",
            "can not be called by other contracts")
    assert(chainhelper:is_owner(), "owner only")

    amount = _checkTokenAmount(amount, 1, TOKEN_AMOUNT_MAX)

    read_list = {
        public_data = {
            platform_fee = true,
        },
    }
    chainhelper:read_chain()

    assert(amount <= public_data.platform_fee, "not enough fee to withdraw")
    _transferOut(COCOS_SYMBOL, amount)

    if target_account ~= contract_base_info.caller then
        chainhelper:transfer_from_caller(target_account, amount, COCOS_SYMBOL, true)
    end

    public_data.platform_fee = public_data.platform_fee - amount

    write_list = {
        public_data = {
            platform_fee = true,
        },
    }
    chainhelper:write_chain()
end