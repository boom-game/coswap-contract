local MORTGAGE_TOKEN_SYMBOL = "COCOS"
local MORTGAGE_TOKEN_ACCURACY = 100000

local MINING_TOKEN_SYMBOL = "KKKK"
local MINING_TOKEN_ACCURACY = 100000
local TOTAL_MINING_AMOUNT = 90000 * MINING_TOKEN_ACCURACY
local RELEASED_DURATION = 60 * 60 * 24 * 18

local MIN_AMOUNT = 10000 * MORTGAGE_TOKEN_ACCURACY

--private 检查整数（字符串）
local function isInteger(str)
    local num = tonumber(str)
    return num and (num - math.floor(num) == 0)
end

--private 读取链上数据
local function readAll()
    read_list = {
        public_data = {
            _mortgage_set = true,
            _unclaimed_set = true,
            _start_mining_time = true,
            _update_mine_amount = true,
        }
    }
    chainhelper:read_chain()
end

--private 写入链上数据
local function writeAll()
    write_list = {
        public_data = {
            _mortgage_set = true,
            _unclaimed_set = true,
            _start_mining_time = true,
            _update_mine_amount = true,
        }
    }
    chainhelper:write_chain()
end

--private 更新挖矿情况
local function updateUnclaimed()
    read_list = {
        public_data = {
            _mortgage_set = true,
            _unclaimed_set = true,
            _start_mining_time = true,
            _update_mine_amount = true,
        }
    }
    chainhelper:read_chain()

    if public_data._start_mining_time <= 0 then
        return
    end

    --计算新矿量
    local released_time = math.min(chainhelper:time() - public_data._start_mining_time, RELEASED_DURATION)
    local released_amount = math.min(math.ceil((TOTAL_MINING_AMOUNT / RELEASED_DURATION) * released_time), TOTAL_MINING_AMOUNT)

    local mine_amount = released_amount - public_data._update_mine_amount
    if mine_amount <= 0 then
        return
    end

    --按比例划分
    local total_mortgage = 0
    for account, mortgage in pairs(public_data._mortgage_set) do
        total_mortgage = total_mortgage + mortgage
    end

    if total_mortgage == 0 then
        return
    end

    local real_mine_amount = 0
    local mine_factor = mine_amount / total_mortgage
    for account, mortgage in pairs(public_data._mortgage_set) do
        local mine = math.floor(mortgage * mine_factor)
        public_data._unclaimed_set[account] = (public_data._unclaimed_set[account] or 0) + mine
        real_mine_amount = real_mine_amount + mine
    end

    public_data._update_mine_amount = public_data._update_mine_amount + real_mine_amount

    write_list = {
        public_data = {
            _unclaimed_set = true,
            _update_mine_amount = true,
        }
    }
    chainhelper:write_chain()
end

--public 初始化 owner only
function init()
    assert(contract_base_info.invoker_contract_id == "1.16.0", "Not to be called by any other contracts!")
    assert(chainhelper:is_owner(), "Unauthorized!")

    readAll()

    public_data._mortgage_set = public_data._mortgage_set or {}

    public_data._unclaimed_set = public_data._unclaimed_set or {}

    public_data._start_mining_time = public_data._start_mining_time or 0

    public_data._update_mine_amount = public_data._update_mine_amount or 0

    writeAll()

end

--public 抵押资产
function mortgage(mortgage_amount)
    assert(isInteger(mortgage_amount), "mortgage_amount should be integer!")
    mortgage_amount = tonumber(mortgage_amount)
    assert(mortgage_amount > 0 and mortgage_amount <= chainhelper:integer_max(),
            "mortgage_amount should be in (0, "..chainhelper:integer_max().."]")
    assert(mortgage_amount >= MIN_AMOUNT, "mortgage at least "..MIN_AMOUNT.." "..MORTGAGE_TOKEN_SYMBOL)

    updateUnclaimed()

    local account = contract_base_info.caller

    read_list = {
        public_data = {
            _mortgage_set = true,
            _start_mining_time = true,
        }
    }
    chainhelper:read_chain()

    if public_data._start_mining_time > 0 then
        assert(chainhelper:time() - public_data._start_mining_time <= RELEASED_DURATION, "out of mining time")
    end

    --转账
    if contract_base_info.caller ~= contract_base_info.owner then
        chainhelper:transfer_from_caller(contract_base_info.owner, mortgage_amount, MORTGAGE_TOKEN_SYMBOL, true)
    end
    chainhelper:adjust_lock_asset(MORTGAGE_TOKEN_SYMBOL, mortgage_amount)

    --第一个抵押开始挖矿
    if public_data._start_mining_time <= 0 then
        public_data._start_mining_time = chainhelper:time()
    end

    public_data._mortgage_set[account] = (public_data._mortgage_set[account] or 0) + mortgage_amount

    write_list = {
        public_data = {
            _mortgage_set = true,
            _start_mining_time = true,
        }
    }
    chainhelper:write_chain()
end

--public 提取矿币
function claim()
    updateUnclaimed()

    local account = contract_base_info.caller

    read_list = {
        public_data = {
            _unclaimed_set = true,
        }
    }
    chainhelper:read_chain()

    local unclaimed_amount = public_data._unclaimed_set[account] or 0
    assert(unclaimed_amount > 0, "no mine to claim")

    if contract_base_info.caller ~= contract_base_info.owner then
        chainhelper:transfer_from_owner(contract_base_info.caller, unclaimed_amount, MINING_TOKEN_SYMBOL, true)
    end

    public_data._unclaimed_set[account] = 0

    write_list = {
        public_data = {
            _unclaimed_set = true,
        }
    }
    chainhelper:write_chain()
end

--public 赎回抵押资产
function redeem(redeem_amount)
    assert(isInteger(redeem_amount), "redeem_amount should be integer!")
    redeem_amount = tonumber(redeem_amount)
    assert(redeem_amount > 0 and redeem_amount <= chainhelper:integer_max(),
            "redeem_amount should be in (0, "..chainhelper:integer_max().."]")

    updateUnclaimed()

    local account = contract_base_info.caller

    read_list = {
        public_data = {
            _mortgage_set = true,
        }
    }
    chainhelper:read_chain()

    local mortgage_amount = public_data._mortgage_set[account] or 0
    assert(mortgage_amount > 0, "no mortgage to redeem")
    assert(redeem_amount <= mortgage_amount, "redeem larger than mortgage")

    public_data._mortgage_set[account] = mortgage_amount - redeem_amount

    chainhelper:adjust_lock_asset(MORTGAGE_TOKEN_SYMBOL, -redeem_amount)
    --转账
    if contract_base_info.caller ~= contract_base_info.owner then
        chainhelper:transfer_from_owner(contract_base_info.caller, redeem_amount, MORTGAGE_TOKEN_SYMBOL, true)
    end

    write_list = {
        public_data = {
            _mortgage_set = true,
        }
    }
    chainhelper:write_chain()
end

--public 移除所有质押 owner only
function removeAllMortgage()
    assert(contract_base_info.invoker_contract_id == "1.16.0", "Not to be called by any other contracts!")
    assert(chainhelper:is_owner(), "Unauthorized!")

    updateUnclaimed()

    read_list = {
        public_data = {
            _mortgage_set = true,
        }
    }
    chainhelper:read_chain()

    for account, mortgage in pairs(public_data._mortgage_set) do
        chainhelper:adjust_lock_asset(MORTGAGE_TOKEN_SYMBOL, -mortgage)
        --转账
        if contract_base_info.caller ~= contract_base_info.owner then
            chainhelper:transfer_from_owner(account, mortgage, MORTGAGE_TOKEN_SYMBOL, true)
        end
        public_data._mortgage_set[account] = 0
    end

    write_list = {
        public_data = {
            _mortgage_set = true,
        }
    }
    chainhelper:write_chain()
end