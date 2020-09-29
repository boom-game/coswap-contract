--手续费抽成
local FUND_RATE = 0.00

local MOON_RATE = 0.0

local DAY_SEC=86400

local MINE_TOKEN = "CFSTEST"
local MINE_TOKEN_ACCURACY = 5
local BLOCK_CUT=1209600
local MINE_FUND = "coswap-fund"
local TO_MOON = "coswap-moon"


-- 大数计算库
--local CONTRACT_BIGNUMBER = "contract.mybignum"
--local CONTRACT_CROSWAP = "contract.pigoneegg" -- 测试网的croswap合约
local CONTRACT_CROSWAP = "contract.croswap" -- 测试网的croswap合约





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

    chainhelper:read_chain()
    public_data.test_check_lp.lp=lp
    public_data.test_check_lp.token_symbol=token_symbol
    public_data.test_check_lp.liquidity=liquidity
    chainhelper:write_chain()
end


function init()
    assert(chainhelper:is_owner(),'no auth')
    chainhelper:read_chain()
    assert(public_data.inited == nil,"has init")
    public_data = {}
    public_data.inited=true
    public_data.last_mine_time=0
    public_data.last_block_num=0
    public_data.last_mine_award="0"

    public_data.test_check_lp={}
    public_data.stake_cash_pool={}
    public_data.stake_cros_lp_pool={}
    chainhelper:write_chain()
end

function reset()
    assert(chainhelper:is_owner(),'no auth')
    chainhelper:read_chain()
    public_data = {}
    chainhelper:write_chain()
end


function reset_user()
    chainhelper:read_chain()
    private_data = {}
    chainhelper:write_chain()
end


function add_pool(type,sym,weight,name,version,unit)
    chainhelper:read_chain()
    assert(chainhelper:is_owner(),'no auth')
    assert(type ~= nil,"type not found")
    if(type == "cash") then
        local pool_pair={}
        pool_pair.type=type
        pool_pair.unit=unit
        pool_pair.weight=weight
        pool_pair.sym=sym
        pool_pair.name=sym
        pool_pair.mask="0"
        pool_pair.keys="0"
        table.insert(public_data.stake_cash_pool,pool_pair)
    elseif(type == "cros") then
        local pool_pair={}
        pool_pair.type=type
        pool_pair.weight=weight
        pool_pair.name=name
        pool_pair.version=tonumber(version)
        pool_pair.mask="0"
        pool_pair.keys="0"
        table.insert(public_data.stake_cros_lp_pool,pool_pair)
    else
        assert(false,"type not support")
    end
    chainhelper:write_chain()
end

function modify_pool(inx,type,sym,weight,name,version,unit)
    chainhelper:read_chain()
    inx=tonumber(inx)
    assert(inx>0,"inx must postive")
    assert(chainhelper:is_owner(),'no auth')
    assert(type ~= nil,"type not found")
    if(type == "cash") then
        local pool_pair=public_data.stake_cash_pool[inx]
        pool_pair.type=type
        pool_pair.unit=unit
        pool_pair.weight=weight
        pool_pair.sym=sym
        pool_pair.name=sym
        public_data.stake_cash_pool[inx]=pool_pair
    elseif(type == "cros") then
        local pool_pair=public_data.stake_cros_lp_pool[inx]
        pool_pair.type=type
        pool_pair.weight=tonumber(weight)
        pool_pair.name=name
        pool_pair.version=tonumber(version)
        public_data.stake_cros_lp_pool[inx]=pool_pair
    else
        assert(false,"type not support")
    end
    chainhelper:write_chain()
end


--抵押货币
function stake_cash(inx,amount,tax_rate)
    tick_mine()
    chainhelper:read_chain()
    inx=tonumber(inx)
    tax_rate=tonumber(tax_rate)
    assert(inx > 0,"inx not invalidate")
    assert(inx ~= nil,"inx not invalidate")
    assert(compare(amount,"0")==1,"amount must positive")
    assert(tax_rate>=0 and tax_rate<=0.05,"tax_rate must positive")
    local now_time_sec=math.floor(chainhelper:time())

    local cash_pair=nil
    for i, v in pairs(public_data.stake_cash_pool) do
        if(i == inx) then
            cash_pair = v
        end
    end
    assert(cash_pair ~= nil,"pair not support")
    amount=toDecimal(amount,cash_pair.unit)
    local key_amount= add(amount,mul(mul(tax_rate,1000),amount))
    assert(compare(key_amount,"0")==1,"key_amount must positive")

    local stake_cash_list = private_data.stake_cash_list
    if(stake_cash_list == nil) then
        stake_cash_list={}
        private_data.stake_cash_list=stake_cash_list
    end
    local stake_info = stake_cash_list[inx]
    if(stake_info == nil) then
        stake_info={}
    end
    stake_info.inx=inx
    stake_info.name=cash_pair.sym
    if(stake_info.cash_items == nil) then
        stake_info.cash_items={}
    end
    stake_cash_list[inx]=stake_info
    local item_size=0
    for i, v in pairs(stake_info.cash_items) do
        item_size=item_size+1
    end
    assert(item_size<10,"stake too many times!")
    local cash_item={}
    cash_item.inx=inx
    cash_item.name=cash_pair.sym
    cash_item.amount=amount
    cash_item.keys=key_amount
    cash_item.mask=mul(key_amount,cash_pair.mask)
    cash_item.tax_rate = tax_rate
    cash_item.tax_fee = "0"
    cash_item.drawed = "0"
    cash_item.start_time=math.floor(chainhelper:time())
    cash_item.check_time=math.floor(chainhelper:time())
    assert(stake_info.cash_items[now_time_sec] ==  nil,"stake too fast!")
    stake_info.cash_items[now_time_sec] = cash_item
    cash_pair.keys=add(cash_pair.keys,key_amount)

    public_data.stake_cash_pool[inx]=cash_pair
    private_data.stake_cash_list[inx]=stake_info

    if(public_data.last_mine_time==0) then
        --首次质押即为挖矿开始
        public_data.start_mine_time=math.floor(chainhelper:time())
        public_data.last_mine_time=math.floor(chainhelper:time())
    end
    chainhelper:transfer_from_caller(contract_base_info.owner, toBigInteger(mul(amount,math.pow(10,cash_pair.unit))), cash_pair.sym, true)
    chainhelper:write_chain()

end





--解压货币
function draw_cash(inx,un_stake)
    tick_mine()
    chainhelper:read_chain()
    inx=tonumber(inx)
    un_stake=tonumber(un_stake)
    assert(inx > 0 ,"inx must positive")
    local cash_pair=public_data.stake_cash_pool[inx]
    assert(cash_pair ~= nil,"pair not found")
    local stake_cash_list = private_data.stake_cash_list
    assert(stake_cash_list ~= nil,"stake list not found")
    local stake_info = stake_cash_list[inx]
    assert(stake_info ~= nil,"stake info not found")
    assert(stake_info.cash_items ~= nil,"cash items not found")
    local now_time_sec=math.floor(chainhelper:time())
    local profit = "0"
    local fire_tax_fee="0"
    local extra_fee="0"
    local total_keys="0"
    local re_fee="0"

    for i, v in pairs(stake_info.cash_items) do
        local tmp_profit= sub(mul(cash_pair.mask,v.keys),v.mask)
        profit = add(profit,tmp_profit)
        if(v.drawed == nil) then
            v.drawed="0"
        end
        v.drawed=add(v.drawed,tmp_profit)
        v.mask = mul(cash_pair.mask,v.keys)
        local pass_sec=now_time_sec-v.check_time
        if(pass_sec>0) then
            v.tax_rate=0
            local tax_fee = mul(pass_sec,div(mul(v.amount,v.tax_rate),DAY_SEC))
            local user_amount=v.amount
            local last_tax_fee = v.tax_fee
            local total_tax_fee = add(tax_fee,v.tax_fee)

            if(compare(user_amount,last_tax_fee) >= 0 and compare(user_amount,total_tax_fee) >= 0) then
                fire_tax_fee=add(fire_tax_fee,tax_fee)
            elseif(compare(total_tax_fee,user_amount) >= 0 and compare(user_amount,last_tax_fee) >= 0) then
                extra_fee=add(extra_fee,sub(total_tax_fee,user_amount))
                fire_tax_fee=add(fire_tax_fee,tax_fee)
            elseif(compare(total_tax_fee,user_amount) >= 0 and compare(last_tax_fee,user_amount) >= 0) then
                extra_fee=add(extra_fee,tax_fee)
            end
            v.check_time=now_time_sec
            v.tax_fee=total_tax_fee
        end

        --if(compare(v.amount,v.tax_fee) >= 0) then
        --    re_fee=add(re_fee,sub(v.amount,v.tax_fee))
        --end
        re_fee=add(re_fee,v.amount)
        total_keys=add(total_keys,v.keys)
        stake_info.cash_items[i]=v
    end

    profit=toDecimal(profit,MINE_TOKEN_ACCURACY)
    if(compare(profit,"0")==1) then
        chainhelper:transfer_from_owner(contract_base_info.caller, toBigInteger(mul(profit,math.pow(10,MINE_TOKEN_ACCURACY))), MINE_TOKEN, true)
    end

    --质押时间过久，手续费已经把本金扣完
    extra_fee=toDecimal(extra_fee,cash_pair.unit)
    if(compare(extra_fee,"0")==1) then
        chainhelper:transfer_from_caller(contract_base_info.owner, toBigInteger(mul(extra_fee,math.pow(10,cash_pair.unit))), cash_pair.sym, true)
    end

    local all_tax_fee=add(fire_tax_fee,extra_fee)
    local moon_fee=mul(all_tax_fee,MOON_RATE)
    local fund_fee=sub(all_tax_fee,moon_fee)

    fund_fee=toDecimal(fund_fee,cash_pair.unit)
    if(compare(fund_fee,"0") == 1) then
        chainhelper:transfer_from_owner(MINE_FUND, toBigInteger(mul(fund_fee,math.pow(10,cash_pair.unit))), cash_pair.sym, true)
    end

    moon_fee=toDecimal(moon_fee,cash_pair.unit)
    if(compare(moon_fee,"0") == 1) then
        chainhelper:transfer_from_owner(TO_MOON, toBigInteger(mul(moon_fee,math.pow(10,cash_pair.unit))), cash_pair.sym, true)
    end

    if(un_stake==1) then
        re_fee=toDecimal(re_fee,cash_pair.unit)
        if(compare(re_fee,"0") == 1) then
            chainhelper:transfer_from_owner(contract_base_info.caller, toBigInteger(mul(re_fee,math.pow(10,cash_pair.unit))), cash_pair.sym, true)
        end
        cash_pair.keys=sub(cash_pair.keys,total_keys)
        stake_info=nil
    end

    public_data.stake_cash_pool[inx]=cash_pair
    private_data.stake_cash_list[inx]=stake_info
    chainhelper:write_chain()
end



function tick_mine()
    chainhelper:read_chain()

    local nowtime=math.floor(chainhelper:time())
    local last_mine_time = math.floor(public_data.last_mine_time)
    local last_block_num = math.floor(public_data.last_block_num)
    local last_mine_award = public_data.last_mine_award
    local fly_time = nowtime - last_mine_time
    assert(fly_time >= 0, "fly time error")
    local fly_block = fly_time * 2
    if (last_mine_time > 0 and fly_block > 0) then
        local total_block = fly_block + last_block_num
        local cut_times = math.floor(total_block / BLOCK_CUT)
        local extra_block = total_block - cut_times * BLOCK_CUT
        local cut_rate = 0.9
        local now_rate = 1
        local init_award = 1
        local total_mine_award = "0"
        for i = 1, cut_times do
            total_mine_award = add(total_mine_award, mul(init_award, mul(BLOCK_CUT, now_rate)))
            now_rate = mul(now_rate, cut_rate)
        end
        if (extra_block > 0) then
            total_mine_award = add(total_mine_award, mul(extra_block, now_rate))
        end
        total_mine_award = toDecimal(total_mine_award, 10)
        local now_mine_award = sub(total_mine_award, last_mine_award)
        assert(compare(now_mine_award, "0") >= 0, "mine award must positive")
        local dev_mine_award = mul(now_mine_award,FUND_RATE)
        if(compare(dev_mine_award,"0") == 1) then
            now_mine_award=sub(now_mine_award,dev_mine_award)
            chainhelper:transfer_from_owner(MINE_FUND, toBigInteger(mul(dev_mine_award,math.pow(10,MINE_TOKEN_ACCURACY))), MINE_TOKEN, true)
        end
        public_data.last_mine_time = nowtime
        public_data.last_block_num = total_block
        public_data.last_mine_award = total_mine_award

        local total_mine_weight = 0
        if(public_data.stake_cash_pool ~= nil) then
            local stake_cash_pool=public_data.stake_cash_pool
            for i, v in pairs(stake_cash_pool) do
                if(compare(v.keys,"0")==1) then
                    total_mine_weight=total_mine_weight+v.weight
                end
            end
        end
        if(public_data.stake_cros_lp_pool ~= nil) then
            for i, v in pairs(public_data.stake_cros_lp_pool) do
                if(compare(v.keys,"0")==1) then
                    total_mine_weight=total_mine_weight+v.weight
                end
            end
        end
        if(total_mine_weight>0) then
            local per_pool_award=div(now_mine_award,total_mine_weight)
            if(public_data.stake_cash_pool ~= nil) then
                local stake_cash_pool=public_data.stake_cash_pool
                for i, v in pairs(stake_cash_pool) do
                    if(compare(v.keys,"0")==1) then
                        local profit_per_key=div(mul(per_pool_award,v.weight),v.keys)
                        v.mask=add(v.mask,profit_per_key)
                        stake_cash_pool[i]=v
                    end
                end
                public_data.stake_cash_pool=stake_cash_pool
            end
            if(public_data.stake_cros_lp_pool ~= nil) then
                local stake_cros_lp_pool=public_data.stake_cros_lp_pool
                for i, v in pairs(stake_cros_lp_pool) do
                    if(compare(v.keys,"0")==1) then
                        local profit_per_key=div(mul(per_pool_award,v.weight),v.keys)
                        v.mask=add(v.mask,profit_per_key)
                        stake_cros_lp_pool[i]=v
                    end
                end
                public_data.stake_cros_lp_pool=stake_cros_lp_pool
            end
        end
        if(total_mine_weight>0) then
            chainhelper:write_chain()
        end
    end
end


--抵押Cros的流动性凭证
function stake_cros_lp(lp_id)
    tick_mine()
    chainhelper:read_chain()
    lp_id=tostring(lp_id)

    _invokeContractFunction(CONTRACT_CROSWAP, "checkLP", lp_id)
    local lp = cjson.decode(cjson.decode(chainhelper:get_nft_asset(lp_id)).base_describe)
    assert(lp ~= nil ,"lp not found")
    local lpname=lp.name
    local lpversion=tonumber(lp.version)
    local inx=-1
    local cros_lp_pair=nil
    for i, v in pairs(public_data.stake_cros_lp_pool) do
        if(v.version == lpversion and v.name == lpname) then
            inx=i
            cros_lp_pair = v
        end
    end
    assert(inx > 0 and cros_lp_pair ~= nil,"pair not support")
    local stake_cros_lp_list = private_data.stake_cros_lp_list
    if(stake_cros_lp_list == nil) then
        stake_cros_lp_list={}
        private_data.stake_cros_lp_list=stake_cros_lp_list
    end
    local stake_info = stake_cros_lp_list[inx]
    if(stake_info == nil) then
        stake_info={}
    end
    stake_info.inx=inx
    stake_info.name=lpname
    stake_info.icon=lp.icon
    if(stake_info.lp_items == nil) then
        stake_info.lp_items={}
    end
    if(stake_info.lp_share == nil) then
        stake_info.lp_share={}
        stake_info.lp_share.keys="0"
        stake_info.lp_share.mask="0"
        stake_info.lp_share.drawed="0"
    end
    stake_cros_lp_list[inx]=stake_info
    assert(stake_info.lp_items[lp_id]==nil,"lp_id exists!")
    local lp_size=0
    for i, v in pairs(stake_info.lp_items) do
        lp_size=lp_size+1
    end
    assert(lp_size<10,"too many lp in one pair!")
    local lp_item={}
    lp_item.id=lp_id
    lp_item.liquidity=lp.liquidity
    stake_info.lp_items[lp_id]=lp_item
    cros_lp_pair.keys=add(cros_lp_pair.keys,lp.liquidity)
    stake_info.lp_share.keys=add(stake_info.lp_share.keys,lp.liquidity)
    assert(compare(lp.liquidity,"0")==1,"liquidity must positive")
    stake_info.lp_share.mask=add(stake_info.lp_share.mask,mul(lp.liquidity,cros_lp_pair.mask))
    public_data.stake_cros_lp_pool[inx]=cros_lp_pair

    private_data.stake_cros_lp_list[inx]=stake_info
    if(public_data.last_mine_time==0) then
        --首次质押即为挖矿开始
        public_data.start_mine_time=math.floor(chainhelper:time())
        public_data.last_mine_time=math.floor(chainhelper:time())
    end
    chainhelper:transfer_nht_from_caller(contract_base_info.owner, lp_id, true)
    chainhelper:write_chain()
end

--提取挖矿收益
function draw_cros_mine(inx,un_stake)
    tick_mine()
    chainhelper:read_chain()

    inx=tonumber(inx)
    un_stake=tonumber(un_stake)
    assert(inx > 0 ,"inx must positive")
    local cros_lp_pair=public_data.stake_cros_lp_pool[inx]
    assert(cros_lp_pair ~= nil,"pair not found")
    local stake_cros_lp_list = private_data.stake_cros_lp_list
    assert(stake_cros_lp_list ~= nil,"stake list not found")
    local stake_info = stake_cros_lp_list[inx]
    assert(stake_info ~= nil,"stake info not found")

    local profit = cros_lp_pair.mask * stake_info.lp_share.keys - stake_info.lp_share.mask
    profit=toDecimal(profit,MINE_TOKEN_ACCURACY)
    assert(compare(profit,"0") == 1,"profit is to small")
    chainhelper:transfer_from_owner(contract_base_info.caller, toBigInteger(mul(profit,math.pow(10,MINE_TOKEN_ACCURACY))), MINE_TOKEN, true)

    if(un_stake==1) then
        cros_lp_pair.keys=sub(cros_lp_pair.keys,stake_info.lp_share.keys)
        stake_info.lp_share.keys="0"
        stake_info.lp_share.mask="0"
        stake_info.lp_share.drawed=add(stake_info.lp_share.drawed,profit)
        for i, v in pairs(stake_info.lp_items) do
            chainhelper:transfer_nht_from_owner(contract_base_info.caller, v.id, true)
        end
        stake_info.lp_items={}
    else
        stake_info.lp_share.mask=cros_lp_pair.mask * stake_info.lp_share.keys
        stake_info.lp_share.drawed=add(stake_info.lp_share.drawed,profit)
    end
    public_data.stake_cros_lp_pool[inx]=cros_lp_pair
    private_data.stake_cros_lp_list[inx]=stake_info
    chainhelper:write_chain()
end



function test()
    local bn=import_contract("contract.decimal")
end

--提取挖矿收益
function test_cros_mine_profit(inx)
    tick_mine()
    chainhelper:read_chain()

    inx=tonumber(inx)
    assert(inx > 0 ,"inx must positive")
    local cros_lp_pair=public_data.stake_cros_lp_pool[inx]
    assert(cros_lp_pair ~= nil,"pair not found")
    local stake_cros_lp_list = private_data.stake_cros_lp_list
    assert(stake_cros_lp_list ~= nil,"stake list not found")
    local stake_info = stake_cros_lp_list[inx]
    assert(stake_info ~= nil,"stake info not found")

    local profit = cros_lp_pair.mask * stake_info.lp_share.keys - stake_info.lp_share.mask
    profit=toDecimal(profit,MINE_TOKEN_ACCURACY)
    assert(compare(profit,"0") == 1,"profit is to small")
    chainhelper:log("profit:"..profit)
end

function transfer_nht(from,to,lp_id)
    from=tostring(from)
    to=tostring(to)
    assert(from ~= to,"from != to")
    chainhelper:log("owner:"..contract_base_info.owner..",caller:"..contract_base_info.caller)
    if(from==contract_base_info.owner and to == contract_base_info.caller) then
        chainhelper:transfer_nht_from_owner(contract_base_info.caller, lp_id, true)
    elseif(from==contract_base_info.caller and to == contract_base_info.owner) then
        chainhelper:transfer_nht_from_caller(contract_base_info.owner, lp_id, true)
    else
        assert(false,"nothing to do")
    end
    --"owner:1.2.265386,caller:1.2.203309"
end

























































-----------------------------------------------------------------------


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