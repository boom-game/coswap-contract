--手续费抽成
local FUND_RATE = 0.05

local MOON_RATE = 0.1
local PROFIT_RATE=0.7

local DAY_SEC=86400

local MAIN_TOKEN = "COCOS"
local MINE_TOKEN_ACCURACY = 5
local MAIN_TOKEN_ACCURACY = 5
local BLOCK_CUT=1209600
local MINE_FUND = "coswap-fund"
local TO_MOON = "coswap-moon"

local pro_start_time=1600776000

local CONTRACT_CROSWAP = "contract.croswap"

local CONTRACT_BIGNUMBER = "contract.bignum"

--测试配置
local MINE_TOKEN = "CFSTEST"
local CONTRACT_ASSET = "contract.assettest"

--正式配置
--local MINE_TOKEN = "CFS"
--local CONTRACT_ASSET = "contract.coasset"

local bignum = nil

local function bn()
    if(bignum==nil) then
        bignum = import_contract(CONTRACT_BIGNUMBER)
    end
    return bignum
end


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



local function _safe_transfer_from_owner(to,amount,sym,log)
    _invokeContractFunction(CONTRACT_ASSET,'safe_transfer_from_owner',to,amount,sym,log)
    chainhelper:transfer_from_owner(to, amount, sym, log)
end

local function _safe_transfer_from_caller(to,amount,sym,log)
    chainhelper:transfer_from_caller(to, amount, sym, log)
    _invokeContractFunction(CONTRACT_ASSET,'safe_transfer_from_caller',to,amount,sym,log)
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

function print_now()
    local now_time_sec=math.floor(chainhelper:time())
    chainhelper:log("现在时间"..now_time_sec)
end

--function reset()
--    assert(chainhelper:is_owner(),'no auth')
--    chainhelper:read_chain()
--    public_data = {}
--    chainhelper:write_chain()
--end
--
--
--function reset_user()
--    chainhelper:read_chain()
--    private_data = {}
--    chainhelper:write_chain()
--end

function testbn1()
    local bnxx = import_contract(CONTRACT_BIGNUMBER)
    local a=bnxx.add(1,1)
end

function testbn2()
    local bnn=bn()
    local a= bnn.add(1,1)
end

function check_start()
    local now_time_sec=math.floor(chainhelper:time())
    assert(now_time_sec>pro_start_time,'2020年9月22日晚8点整开始')
end

function tick_moon(buy)
    buy=tonumber(buy)
    chainhelper:read_chain()

    local pub_moon_record=public_data.moon_record
    local pri_moon_record=private_data.moon_record
    local now_time_sec = math.floor(chainhelper:time())
    if(pub_moon_record == nil) then
        pub_moon_record={}
        pub_moon_record.last_tick_time=0
        pub_moon_record.last_moon_time=0
        public_data.moon_record=pub_moon_record
    end
    if(pri_moon_record == nil) then
        pri_moon_record={}
        pri_moon_record.last_tick_time=0
        private_data.moon_record=pri_moon_record
    end
    if(buy==1) then
        assert(chainhelper:is_owner(),'no auth')
        _invokeContractFunction('contract.cfstomoon','buy_cros_cfs')
        pub_moon_record.last_moon_time=now_time_sec
    else
        if((now_time_sec-pub_moon_record.last_moon_time)>(60*60)) then
            if((now_time_sec-pub_moon_record.last_tick_time)>(10) and (now_time_sec-pri_moon_record.last_tick_time)>(60*60)) then
                local rd=chainhelper:random()%1000
                pub_moon_record.last_rand_num=rd
                pub_moon_record.last_tick_user=contract_base_info.caller
                if(rd>=990) then
                    _invokeContractFunction('contract.cfstomoon','buy_cros_cfs')
                    pub_moon_record.last_moon_time=now_time_sec
                end
            end
        end
    end
    pub_moon_record.last_tick_time=now_time_sec
    pri_moon_record.last_tick_time=now_time_sec
    public_data.moon_record=pub_moon_record
    private_data.moon_record=pri_moon_record
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
        pool_pair.weight=tonumber(weight)
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

function init_cfs_cocos()
    chainhelper:read_chain()

    local cfs_profit_table=public_data.cfs_profit_table
    if(cfs_profit_table==nil) then
        cfs_profit_table={}
        cfs_profit_table.keys="0"
        cfs_profit_table.cocos_in="0"
        cfs_profit_table.cocos_out="0"
        cfs_profit_table.cocos_mask="0"
    end
    public_data.cfs_profit_table=cfs_profit_table
    chainhelper:write_chain()
end

--
--function reset_cfs_user()
--    chainhelper:read_chain()
--    local stake_profit_table=private_data.stake_profit_table
--    stake_profit_table={}
--    stake_profit_table.keys="0"
--    stake_profit_table.cocos_in="0"
--    stake_profit_table.cocos_out="0"
--    stake_profit_table.cocos_mask="0"
--    private_data.stake_profit_table=stake_profit_table
--    chainhelper:write_chain()
--end

function add_cfs_cocos(amount)
    check_start()
    tick_mine()
    chainhelper:read_chain()

    assert(bn().compare(amount,"0")==1,"amount must positive")
    assert(bn().compare(amount,"100000000000") == -1 , "amount to big!")
    local now_time_sec=math.floor(chainhelper:time())
    local cfs_profit_table=public_data.cfs_profit_table
    if(cfs_profit_table~=nil and bn().compare(cfs_profit_table.keys,"0") ==1 ) then
        amount=bn().toDecimal(amount,MAIN_TOKEN_ACCURACY)
        local profitPerKey = bn().div(amount,cfs_profit_table.keys)
        cfs_profit_table.cocos_mask=bn().add(cfs_profit_table.cocos_mask,profitPerKey)
        cfs_profit_table.cocos_in=bn().add(cfs_profit_table.cocos_in,amount)
        public_data.cfs_profit_table=cfs_profit_table
        _safe_transfer_from_caller(contract_base_info.owner,tonumber(bn().toBigInteger(bn().mul(amount,math.pow(10,MAIN_TOKEN_ACCURACY)))),MAIN_TOKEN,true)
    end
    chainhelper:write_chain()
end

function stake_cfs(amount)
    chainhelper:read_chain()

    assert(bn().compare(amount,"0")==1,"amount must positive")
    assert(bn().compare(amount,"100000000000") == -1 , "amount to big!")

    amount=bn().toDecimal(amount,MINE_TOKEN_ACCURACY)
    local cfs_profit_table=public_data.cfs_profit_table
    assert(cfs_profit_table ~= nil,'cfs_profit_table not found')
    local stake_profit_table=private_data.stake_profit_table
    if(stake_profit_table==nil) then
        stake_profit_table={}
        stake_profit_table.keys="0"
        stake_profit_table.cocos_mask="0"
        stake_profit_table.cocos_out="0"
    end
    stake_profit_table.keys=bn().add(stake_profit_table.keys,amount)
    stake_profit_table.cocos_mask=bn().add(stake_profit_table.cocos_mask,bn().mul(cfs_profit_table.cocos_mask,amount))
    cfs_profit_table.keys=bn().add(cfs_profit_table.keys,amount)
    public_data.cfs_profit_table=cfs_profit_table
    private_data.stake_profit_table=stake_profit_table

    _safe_transfer_from_caller(contract_base_info.owner,tonumber(bn().toBigInteger(bn().mul(amount,math.pow(10,MINE_TOKEN_ACCURACY)))),MINE_TOKEN,true)

    chainhelper:write_chain()
end

function draw_cfs(un_stake)
    un_stake=tonumber(un_stake)
    check_start()
    tick_mine()
    if(un_stake==1) then
        rm_user_vote()
    end
    chainhelper:read_chain()

    local now_time_sec=math.floor(chainhelper:time())
    local cfs_profit_table=public_data.cfs_profit_table
    assert(cfs_profit_table ~= nil,'cfs_profit_table not found')
    local stake_profit_table=private_data.stake_profit_table
    assert(stake_profit_table ~= nil,'stake_profit_table not found')
    local profit = bn().sub(bn().mul(cfs_profit_table.cocos_mask,stake_profit_table.keys),stake_profit_table.cocos_mask)
    cfs_profit_table.cocos_out=bn().add(cfs_profit_table.cocos_out,profit)
    cfs_profit_table.cocos_out=bn().toDecimal(cfs_profit_table.cocos_out,5)
    stake_profit_table.cocos_mask= bn().mul(cfs_profit_table.cocos_mask,stake_profit_table.keys)
    stake_profit_table.cocos_out=bn().add(stake_profit_table.cocos_out,profit)
    if(bn().compare(profit,"0")==1) then
        _safe_transfer_from_owner(contract_base_info.caller,tonumber(bn().toBigInteger(bn().mul(profit,math.pow(10,MAIN_TOKEN_ACCURACY)))),MAIN_TOKEN,true)
    end
    if(un_stake==1) then
        cfs_profit_table.keys=bn().sub(cfs_profit_table.keys,stake_profit_table.keys)
        _safe_transfer_from_owner(contract_base_info.caller,tonumber(bn().toBigInteger(bn().mul(stake_profit_table.keys,math.pow(10,MINE_TOKEN_ACCURACY)))),MINE_TOKEN,true)
        stake_profit_table.keys="0"
        stake_profit_table.cocos_mask="0"
    end
    public_data.cfs_profit_table=cfs_profit_table
    private_data.stake_profit_table=stake_profit_table
    chainhelper:write_chain()
end


function check_vote()
    chainhelper:read_chain()

    local vote_table=public_data.vote_table
    if(vote_table~=nil) then
        local now_time_sec=chainhelper:time()
        for i, v in pairs(vote_table) do
            if(v.end_time<now_time_sec) then
                v.status=-1
            end
            if(v.start_time>now_time_sec) then
                v.status=2
            end
            if(now_time_sec>=v.start_time and now_time_sec<=v.end_time) then
                v.status=1
            end
        end
        public_data.vote_table=vote_table
    end
    chainhelper:write_chain()
end

function add_vote(name,start_time,end_time)
    check_vote()
    start_time=tonumber(start_time)
    end_time=tonumber(end_time)
    assert(chainhelper:is_owner(),'no auth')
    chainhelper:read_chain()

    local vote_table=public_data.vote_table
    if(vote_table==nil) then
        vote_table={}
    end
    for i, v in pairs(vote_table) do
        assert(v.status==0,'last vote not end')
    end
    local vote_item={}
    vote_item.name=name
    vote_item.start_time=start_time
    vote_item.end_time=end_time
    vote_item.status=0
    vote_item.chose_list={}
    table.insert(vote_table,vote_item)
    public_data.vote_table=vote_table
    chainhelper:write_chain()
end

function add_vote_chose_item(inx,name)
    check_vote()
    inx=tonumber(inx)
    assert(chainhelper:is_owner(),'no auth')
    chainhelper:read_chain()

    local vote_table=public_data.vote_table
    local vote_item=vote_table[inx]
    local now_time_sec=chainhelper:time()
    assert(vote_item ~= nil,'vote not found')
    --assert(vote_item.start_time>now_time_sec,'vote is start')
    local chose_item={}
    chose_item.name=name
    chose_item.keys=0
    table.insert(vote_item.chose_list,chose_item)
    vote_table[inx]=vote_item
    public_data.vote_table=vote_table
    chainhelper:write_chain()
end

function send_vote(inx1,inx2)
    check_vote()
    rm_user_vote()
    inx1=tonumber(inx1)
    inx2=tonumber(inx2)
    chainhelper:read_chain()

    assert(private_data.stake_profit_table ~= nil,'你还未质押CFS')
    assert(private_data.stake_profit_table.keys~=nil,'你还未质押CFS')
    assert(bn().compare(private_data.stake_profit_table.keys,"0") == 1,'你还未质押CFS')

    local vote_table=public_data.vote_table
    local vote_item=vote_table[inx1]
    assert(vote_item ~= nil,'vote not found')
    assert(vote_item.status == 1,'vote is start')
    local chose_item=vote_item.chose_list[inx2]
    assert(chose_item ~= nil,'chose not found')

    local user_vote_chose=private_data.user_vote_chose
    user_vote_chose.inx1=inx1
    user_vote_chose.inx2=inx2
    user_vote_chose.keys=tonumber(private_data.stake_profit_table.keys)
    chose_item.keys=chose_item.keys+tonumber(private_data.stake_profit_table.keys)

    vote_item.chose_list[inx2]=chose_item
    vote_table[inx1]=vote_item
    public_data.vote_table=vote_table
    private_data.user_vote_chose=user_vote_chose
    chainhelper:write_chain()
end

function rm_user_vote()
    check_vote()
    chainhelper:read_chain()

    local user_vote_chose=private_data.user_vote_chose
    if(user_vote_chose ~= nil) then
        local inx1=user_vote_chose.inx1
        local inx2=user_vote_chose.inx2
        local keys=user_vote_chose.keys
        if(inx1 ~= nil and inx2 ~= nil and keys ~= nil) then
            if(inx1 >0 and inx2 >0 and keys >0) then
                local vote_table=public_data.vote_table
                if(vote_table ~= nil and vote_table[inx1]~=nil and vote_table[inx1].chose_list~=nil and vote_table[inx1].chose_list[inx2] ~= nil) then
                    local vote_item=vote_table[inx1]
                    if(vote_item.status==1) then
                        local chose_item=vote_table[inx1].chose_list[inx2]
                        chose_item.keys=chose_item.keys-user_vote_chose.keys
                        vote_item.chose_list[inx2]=chose_item
                        vote_table[inx1]=vote_item
                        public_data.vote_table=vote_table
                    end
                end
            end
        end
        user_vote_chose.inx1=0
        user_vote_chose.inx2=0
        user_vote_chose.keys=0
        private_data.user_vote_chose=user_vote_chose
    end
    chainhelper:write_chain()
end

--抵押货币
function stake_cash(inx,amount,tax_rate)
    check_start()
    tick_mine()
    chainhelper:read_chain()

    inx=tonumber(inx)
    tax_rate=tonumber(tax_rate)
    assert(inx > 0,"inx not invalidate")
    assert(inx ~= nil,"inx not invalidate")
    assert(bn().compare(amount,"0")==1,"amount must positive")
    assert(bn().compare(amount,"1000000000000") == -1 , "amount to big!")
    assert(tax_rate>=0 and tax_rate<=0.05,"tax_rate must positive")
    local now_time_sec=math.floor(chainhelper:time())

    local cash_pair=nil
    for i, v in pairs(public_data.stake_cash_pool) do
        if(i == inx) then
            cash_pair = v
        end
    end
    assert(cash_pair ~= nil,"pair not support")
    amount=bn().toDecimal(amount,cash_pair.unit)
    local key_amount= bn().add(amount,bn().mul(bn().mul(tax_rate,1000),amount))
    assert(bn().compare(key_amount,"0")==1,"key_amount must positive")

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
    cash_item.mask=bn().mul(key_amount,cash_pair.mask)
    cash_item.tax_rate = tax_rate
    cash_item.tax_fee = "0"
    cash_item.drawed = "0"
    cash_item.start_time=math.floor(chainhelper:time())
    cash_item.check_time=math.floor(chainhelper:time())
    assert(stake_info.cash_items[now_time_sec] ==  nil,"stake too fast!")
    stake_info.cash_items[now_time_sec] = cash_item
    cash_pair.keys=bn().add(cash_pair.keys,key_amount)

    public_data.stake_cash_pool[inx]=cash_pair
    private_data.stake_cash_list[inx]=stake_info

    if(public_data.last_mine_time==0) then
        --首次质押即为挖矿开始
        public_data.start_mine_time=math.floor(chainhelper:time())
        public_data.last_mine_time=math.floor(chainhelper:time())
    end
    _safe_transfer_from_caller(contract_base_info.owner, tonumber(bn().toBigInteger(bn().mul(amount,math.pow(10,cash_pair.unit)))), cash_pair.sym, true)
    chainhelper:write_chain()

end




--解压货币
function draw_cash(inx,un_stake)
    check_start()
    tick_mine()
    --tick_moon(0)
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
        local tmp_profit= bn().sub(bn().mul(cash_pair.mask,v.keys),v.mask)
        profit = bn().add(profit,tmp_profit)
        if(v.drawed == nil) then
            v.drawed="0"
        end
        v.drawed=bn().add(v.drawed,tmp_profit)
        v.mask = bn().mul(cash_pair.mask,v.keys)
        local pass_sec=now_time_sec-v.check_time
        if(pass_sec>0) then
            local tax_fee = bn().mul(pass_sec,bn().div(bn().mul(v.amount,v.tax_rate),DAY_SEC))
            local user_amount=v.amount
            local last_tax_fee = v.tax_fee
            local total_tax_fee = bn().add(tax_fee,v.tax_fee)

            if(bn().compare(user_amount,last_tax_fee) >= 0 and bn().compare(user_amount,total_tax_fee) >= 0) then
                fire_tax_fee=bn().add(fire_tax_fee,tax_fee)
            elseif(bn().compare(total_tax_fee,user_amount) >= 0 and bn().compare(user_amount,last_tax_fee) >= 0) then
                extra_fee=bn().add(extra_fee,bn().sub(total_tax_fee,user_amount))
                fire_tax_fee=bn().add(fire_tax_fee,tax_fee)
            elseif(bn().compare(total_tax_fee,user_amount) >= 0 and bn().compare(last_tax_fee,user_amount) >= 0) then
                extra_fee=bn().add(extra_fee,tax_fee)
            end
            v.check_time=now_time_sec
            v.tax_fee=total_tax_fee
        end

        if(bn().compare(v.amount,v.tax_fee) >= 0) then
            re_fee=bn().add(re_fee,bn().sub(v.amount,v.tax_fee))
        end
        total_keys=bn().add(total_keys,v.keys)
        stake_info.cash_items[i]=v
    end

    profit=bn().toDecimal(profit,MINE_TOKEN_ACCURACY)
    if(bn().compare(profit,"0")==1) then
        _safe_transfer_from_owner(contract_base_info.caller, tonumber(bn().toBigInteger(bn().mul(profit,math.pow(10,MINE_TOKEN_ACCURACY)))) , MINE_TOKEN, true)
    end

    --质押时间过久，手续费已经把本金扣完
    extra_fee=bn().toDecimal(extra_fee,cash_pair.unit)
    if(bn().compare(extra_fee,"0")==1) then
        _safe_transfer_from_caller(contract_base_info.owner, tonumber(bn().toBigInteger(bn().mul(extra_fee,math.pow(10,cash_pair.unit)))), cash_pair.sym, true)
    end

    local all_tax_fee=bn().add(fire_tax_fee,extra_fee)

    local profit_fee ="0"
    local moon_fee="0"
    if(cash_pair.sym==MAIN_TOKEN) then
        profit_fee=bn().mul(all_tax_fee,PROFIT_RATE)
        moon_fee=bn().mul(all_tax_fee,MOON_RATE)
    else
        moon_fee=bn().mul(all_tax_fee,PROFIT_RATE+MOON_RATE)
    end
    local fund_fee=bn().sub(bn().sub(all_tax_fee,moon_fee),profit_fee)

    if(cash_pair.sym==MAIN_TOKEN) then
        local cfs_profit_table=public_data.cfs_profit_table
        if(cfs_profit_table~=nil and bn().compare(cfs_profit_table.keys,"0") ==1 and bn().compare(profit_fee,"0")==1) then
            profit_fee=bn().toDecimal(profit_fee,MAIN_TOKEN_ACCURACY)
            local profitPerKey = bn().div(profit_fee,cfs_profit_table.keys)
            cfs_profit_table.cocos_mask=bn().add(cfs_profit_table.cocos_mask,profitPerKey)
            cfs_profit_table.cocos_in=bn().add(cfs_profit_table.cocos_in,profit_fee)
            public_data.cfs_profit_table=cfs_profit_table
        end
    end

    fund_fee=bn().toDecimal(fund_fee,cash_pair.unit)
    if(bn().compare(fund_fee,"0") == 1) then
        _safe_transfer_from_owner(MINE_FUND, tonumber(bn().toBigInteger(bn().mul(fund_fee,math.pow(10,cash_pair.unit)))), cash_pair.sym, true)
    end

    moon_fee=bn().toDecimal(moon_fee,cash_pair.unit)
    if(bn().compare(moon_fee,"0") == 1) then
        _safe_transfer_from_owner(TO_MOON, tonumber(bn().toBigInteger(bn().mul(moon_fee,math.pow(10,cash_pair.unit)))), cash_pair.sym, true)
    end

    if(un_stake==1) then
        re_fee=bn().toDecimal(re_fee,cash_pair.unit)
        if(bn().compare(re_fee,"0") == 1) then
            _safe_transfer_from_owner(contract_base_info.caller, tonumber(bn().toBigInteger(bn().mul(re_fee,math.pow(10,cash_pair.unit)))), cash_pair.sym, true)
        end
        cash_pair.keys=bn().sub(cash_pair.keys,total_keys)
        stake_info=nil
    end

    public_data.stake_cash_pool[inx]=cash_pair
    private_data.stake_cash_list[inx]=stake_info
    chainhelper:write_chain()
end



function tick_mine()
    check_start()
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
            total_mine_award = bn().add(total_mine_award, bn().mul(init_award, bn().mul(BLOCK_CUT, now_rate)))
            now_rate = bn().mul(now_rate, cut_rate)
        end
        if (extra_block > 0) then
            total_mine_award = bn().add(total_mine_award, bn().mul(extra_block, now_rate))
        end
        total_mine_award = bn().toDecimal(total_mine_award, 10)
        local now_mine_award = bn().sub(total_mine_award, last_mine_award)
        assert(bn().compare(now_mine_award, "0") >= 0, "mine award must positive")
        local dev_mine_award = bn().mul(now_mine_award,FUND_RATE)
        if(bn().compare(dev_mine_award,"0") == 1) then
            now_mine_award=bn().sub(now_mine_award,dev_mine_award)
            _safe_transfer_from_owner(MINE_FUND, tonumber(bn().toBigInteger(bn().mul(dev_mine_award,math.pow(10,MINE_TOKEN_ACCURACY)))), MINE_TOKEN, true)
        end
        public_data.last_mine_time = nowtime
        public_data.last_block_num = total_block
        public_data.last_mine_award = total_mine_award

        local total_mine_weight = 0
        if(public_data.stake_cash_pool ~= nil) then
            local stake_cash_pool=public_data.stake_cash_pool
            for i, v in pairs(stake_cash_pool) do
                if(bn().compare(v.keys,"0")==1) then
                    total_mine_weight=total_mine_weight+v.weight
                end
            end
        end
        if(public_data.stake_cros_lp_pool ~= nil) then
            for i, v in pairs(public_data.stake_cros_lp_pool) do
                if(bn().compare(v.keys,"0")==1) then
                    total_mine_weight=total_mine_weight+v.weight
                end
            end
        end
        if(total_mine_weight>0) then
            local per_pool_award=bn().div(now_mine_award,total_mine_weight)
            if(public_data.stake_cash_pool ~= nil) then
                local stake_cash_pool=public_data.stake_cash_pool
                for i, v in pairs(stake_cash_pool) do
                    if(bn().compare(v.keys,"0")==1) then
                        local profit_per_key=bn().div(bn().mul(per_pool_award,v.weight),v.keys)
                        v.mask=bn().add(v.mask,profit_per_key)
                        stake_cash_pool[i]=v
                    end
                end
                public_data.stake_cash_pool=stake_cash_pool
            end
            if(public_data.stake_cros_lp_pool ~= nil) then
                local stake_cros_lp_pool=public_data.stake_cros_lp_pool
                for i, v in pairs(stake_cros_lp_pool) do
                    if(bn().compare(v.keys,"0")==1) then
                        local profit_per_key=bn().div(bn().mul(per_pool_award,v.weight),v.keys)
                        v.mask=bn().add(v.mask,profit_per_key)
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
    check_start()
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
    cros_lp_pair.keys=bn().add(cros_lp_pair.keys,lp.liquidity)
    stake_info.lp_share.keys=bn().add(stake_info.lp_share.keys,lp.liquidity)
    assert(bn().compare(lp.liquidity,"0")==1,"liquidity must positive")
    stake_info.lp_share.mask=bn().add(stake_info.lp_share.mask,bn().mul(lp.liquidity,cros_lp_pair.mask))
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
    check_start()
    tick_mine()
    --tick_moon(0)
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

    local profit = bn().sub(bn().mul(cros_lp_pair.mask,stake_info.lp_share.keys),stake_info.lp_share.mask)
    profit=bn().toDecimal(profit,MINE_TOKEN_ACCURACY)
    assert(bn().compare(profit,"0") == 1,"profit is to small")
    _safe_transfer_from_owner(contract_base_info.caller, tonumber(bn().toBigInteger(bn().mul(profit,math.pow(10,MINE_TOKEN_ACCURACY)))) , MINE_TOKEN, true)

    if(un_stake==1) then
        cros_lp_pair.keys=bn().sub(cros_lp_pair.keys,stake_info.lp_share.keys)
        stake_info.lp_share.keys="0"
        stake_info.lp_share.mask="0"
        stake_info.lp_share.drawed=bn().add(stake_info.lp_share.drawed,profit)
        for i, v in pairs(stake_info.lp_items) do
            chainhelper:transfer_nht_from_owner(contract_base_info.caller, v.id, true)
        end
        stake_info.lp_items={}
    else
        stake_info.lp_share.mask= bn().mul(cros_lp_pair.mask,stake_info.lp_share.keys)
        stake_info.lp_share.drawed=bn().add(stake_info.lp_share.drawed,profit)
    end
    public_data.stake_cros_lp_pool[inx]=cros_lp_pair
    private_data.stake_cros_lp_list[inx]=stake_info
    chainhelper:write_chain()
end

