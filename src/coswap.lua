--奖励开发者
local DEV_RATE = 0.0
--奖励抵押平台币
local PLATFORM_RATE = 0.0

local PLATFORM_TOKEN = "CFSTEST"

-- 大数计算库
--local CONTRACT_BIGNUMBER = "contract.bigdecimal"
local CONTRACT_BIGNUMBER = "contract.bignum"


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

function add_platform_pair(sym)
    assert(chainhelper:is_owner(),'no auth')
    if(public_data.platform_table == nil) then
        public_data.platform_table={}
        public_data.platform_table.share_keys="0"
        public_data.platform_table.list={}
    end
    if(public_data.platform_table.list[sym] == nil) then
        public_data.platform_table.list[sym]={}
        public_data.platform_table.list[sym].share_mask='0'
    end
end


function start_mine()
    assert(chainhelper:is_owner(),'no auth')
    chainhelper:read_chain()
    local mine_table=public_data.mine_table
    if(mine_table == nil) then
        mine_table={}
    end
    chainhelper:write_chain()
end



--添加交易对
function add_pair(ratio,type,main_supply,main_sym,main_unit,main_fee, sub_supply,sub_sym,sub_unit,sub_fee)
    assert(chainhelper:is_owner(),'no auth')
    assert(main_sym ~= sub_sym,'from != to')
    assert(type=='bancor' or type=='swap',"type not support")
    chainhelper:read_chain()
    local bn = import_contract(CONTRACT_BIGNUMBER)

    main_supply = bn.toDecimal(main_supply,10)
    sub_supply = bn.toDecimal(sub_supply,10)
    assert((bn.compare(main_supply,0) >= 0) and (bn.compare(sub_supply,0) >= 0), "invalid amount!")
    assert((bn.compare(main_supply,"100000000000") == -1) and (bn.compare(sub_supply,"100000000000") == -1) , "amount to big!")
    if(public_data.pair_table == nil) then
        public_data.pair_table={}
    end

    for inx,trade_pair in pairs(public_data.pair_table) do
        if(trade_pair.main_sym==main_sym and trade_pair.sub_sym==sub_sym) then
            --if(trade_pair.type==type) then
                assert(false,'pair already exists')
            --end
        end
        if(trade_pair.main_sym==sub_sym and trade_pair.sub_sym==main_sym) then
            --if(trade_pair.type==type) then
                assert(false,'pair already exists')
            --end
        end
    end

    if(type=='swap') then
        main_supply="0"
        sub_supply="0"
    end

    trade_pair = {}
    trade_pair.enable =false
    trade_pair.ratio=ratio
    trade_pair.type=type
    if(bn.compare(sub_supply,"0") == 1) then
        trade_pair.price=bn.div(main_supply,bn.mul(sub_supply,ratio))
    else
        trade_pair.price="0"
    end
    trade_pair.trade_mine_pool={}
    trade_pair.main_supply=main_supply
    trade_pair.main_sym=main_sym
    trade_pair.main_unit=bn.toBigInteger(main_unit)
    assert(bn.compare(trade_pair.main_unit,"0")==1,"main uint must > 0")
    trade_pair.main_fee=bn.toDecimal(main_fee,4)
    trade_pair.sub_supply=sub_supply
    trade_pair.sub_sym=sub_sym
    trade_pair.sub_unit=bn.toBigInteger(sub_unit)
    assert(bn.compare(trade_pair.sub_unit,"0")==1,"sub uint must > 0")
    trade_pair.sub_fee=bn.toDecimal(sub_fee,4)
    trade_pair.main_mask='0'
    trade_pair.sub_mask='0'
    trade_pair.share_keys='0'
    table.insert(public_data.pair_table, trade_pair)

    chainhelper:write_chain()
end

--允许交易
function enable_pair(inx)
    assert(chainhelper:is_owner(),'no auth')
    chainhelper:read_chain()
    inx=tonumber(inx)
    assert(public_data.pair_table ~= nil,"pair_table not found!")
    assert(public_data.pair_table[inx] ~= nil,"trade_pair not found!")
    public_data.pair_table[inx].enable = true
    chainhelper:write_chain()
end

--禁止交易
function disable_pair(inx)
    assert(chainhelper:is_owner(),'no auth')
    chainhelper:read_chain()
    inx=tonumber(inx)
    assert(public_data.pair_table ~= nil,"pair_table not found!")
    assert(public_data.pair_table[inx] ~= nil,"trade_pair not found!")
    public_data.pair_table[inx].enable = false
    chainhelper:write_chain()
end

local function bancor_ex(is_buy,amount,ratio,main_supply,sub_supply)
    chainhelper:read_chain()
    local bn=import_contract(CONTRACT_BIGNUMBER)
    if(is_buy) then
        return bn.mul((math.pow(tonumber(bn.add(1,bn.div(amount,main_supply))),tonumber(ratio))-1),sub_supply)
    else
        return bn.mul((1-math.pow(tonumber(bn.sub(1,bn.div(amount,sub_supply))),(1/tonumber(ratio)))) ,main_supply)
    end
    chainhelper:write_chain()
end

local function swap_ex(is_buy,amount,ratio, main_supply,sub_supply)
    chainhelper:read_chain()
    local bn=import_contract(CONTRACT_BIGNUMBER)
    if(is_buy) then
        --return sub_supply-(main_supply*(sub_supply/(main_supply+amount)))
        return bn.sub(sub_supply,bn.mul(main_supply,bn.div(sub_supply,bn.add(main_supply,amount))))
    else
        --return main_supply-(sub_supply*(main_supply/(sub_supply+amount)))
        return bn.sub(main_supply,bn.mul(sub_supply,bn.div(main_supply,bn.add(sub_supply,amount))))
    end
    chainhelper:write_chain()
end

function trade2()
    chainhelper:read_chain()
    local bn=import_contract(CONTRACT_BIGNUMBER)
end

--交易
function trade(inx,from_sym,from_amount,to_sym,to_amount)
    assert(from_sym ~= to_sym,'from != to')
    chainhelper:read_chain()
    local bn=import_contract(CONTRACT_BIGNUMBER)
    from_amount = bn.toDecimal(from_amount,10)
    to_amount = bn.toDecimal(to_amount,10)
    assert((bn.compare(from_amount,0) == 1) and (bn.compare(to_amount,0) == 1), "invalid amount!")
    assert((bn.compare(from_amount,"1000000000") == -1) and (bn.compare(to_amount,"1000000000") == -1) , "amount to big!")
    inx=tonumber(inx)
    assert(inx>0 , "invalid inx!")

    assert(public_data~=nil,'public_data is null')
    assert(public_data.pair_table~=nil,'pair_table is null')
    trade_pair = public_data.pair_table[inx]
    assert(trade_pair~=nil , "trade_pair not exists")
    assert(trade_pair.enable , "trade_pair not enable")
    assert(bn.compare(trade_pair.main_supply,"0")==1 and bn.compare(trade_pair.sub_supply,"0") == 1,"trade pair supply error")
    is_buy=(trade_pair.main_sym==from_sym and trade_pair.sub_sym==to_sym)
    is_sell=(trade_pair.main_sym==to_sym and trade_pair.sub_sym==from_sym)
    assert((is_buy or is_sell),"trade_pair not exists")
    local price_old = trade_pair.price
    local vol="0"

    if(is_buy) then
        local fee = bn.mul(from_amount,trade_pair.main_fee)
        local platform_fee="0"
        local platform_pair=public_data.platform_table.list[from_sym]
        if(platform_pair~=nil and bn.compare(public_data.platform_table.share_keys,"0") == 1) then
            platform_fee=bn.mul(fee,PLATFORM_RATE)
            platform_pair.share_mask=bn.add(platform_pair.share_mask,bn.div(platform_fee,public_data.platform_table.share_keys))
        end
        local dev_fee=bn.mul(fee,DEV_RATE)
        local pair_fee = bn.sub(fee,bn.add(dev_fee,platform_fee))
        local trade_amount = bn.sub(from_amount,fee)
        if(bn.compare(dev_fee,"0") == 1) then
            chainhelper:transfer_from_caller('coswap-fund', bn.mul(dev_fee,math.pow(10,trade_pair.main_unit)), trade_pair.main_sym, true)
        end
        --分成金额
        if(bn.compare(pair_fee,"0") == 1 and bn.compare(trade_pair.share_keys,"0") == 1) then
            local profit_per_key= bn.div(pair_fee,trade_pair.share_keys)
            trade_pair.main_mask=bn.add(trade_pair.main_mask,profit_per_key)
        end
        --交换代币
        if(trade_pair.type=='bancor') then
            vol = bancor_ex(true,trade_amount,trade_pair.ratio,trade_pair.main_supply,trade_pair.sub_supply)
            trade_pair.main_supply=bn.add(trade_pair.main_supply,trade_amount)
            trade_pair.sub_supply=bn.add(trade_pair.sub_supply,vol)
        elseif (trade_pair.type=='swap') then
            vol = swap_ex(true,trade_amount,trade_pair.ratio,trade_pair.main_supply,trade_pair.sub_supply)
            trade_pair.main_supply=bn.add(trade_pair.main_supply,trade_amount)
            trade_pair.sub_supply=bn.sub(trade_pair.sub_supply,vol)
        end
        assert(bn.compare(vol,"0") == 1,'amount error')

        chainhelper:transfer_from_caller(contract_base_info.owner, bn.toBigInteger(bn.mul(from_amount,math.pow(10,trade_pair.main_unit))), trade_pair.main_sym, true)
        chainhelper:transfer_from_owner(contract_base_info.caller, bn.toBigInteger(bn.mul(vol,math.pow(10,trade_pair.sub_unit))), trade_pair.sub_sym, true)

    elseif(is_sell) then
        local fee = bn.mul(from_amount,trade_pair.sub_fee)
        local platform_fee="0"
        local platform_pair=public_data.platform_table.list[from_sym]
        if(platform_pair~=nil and bn.compare(public_data.platform_table.share_keys,"0") == 1) then
            platform_fee=bn.mul(fee,PLATFORM_RATE)
            platform_pair.share_mask=bn.add(platform_pair.share_mask,bn.div(platform_fee,public_data.platform_table.share_keys))
        end
        local dev_fee=bn.mul(fee,DEV_RATE)
        local pair_fee = bn.sub(fee,bn.add(dev_fee,platform_fee))
        local trade_amount = bn.sub(from_amount,fee)
        if(bn.compare(dev_fee,"0") == 1) then
            chainhelper:transfer_from_caller('coswap-fund', bn.mul(dev_fee,math.pow(10,trade_pair.sub_unit)), trade_pair.sub_sym, true)
        end
        --分成金额
        if(bn.compare(pair_fee,"0") == 1 and bn.compare(trade_pair.share_keys,"0") == 1) then
            local profit_per_key= bn.div(pair_fee,trade_pair.share_keys)
            trade_pair.sub_mask=bn.add(trade_pair.sub_mask,profit_per_key)
        end
        --交换代币
        if(trade_pair.type=='bancor') then
            vol = bancor_ex(false,trade_amount,trade_pair.ratio,trade_pair.main_supply,trade_pair.sub_supply)
            trade_pair.main_supply=bn.sub(trade_pair.main_supply,vol)
            trade_pair.sub_supply=bn.sub(trade_pair.sub_supply,trade_amount)
        elseif (trade_pair.type=='swap') then
            vol = swap_ex(false,trade_amount,trade_pair.ratio,trade_pair.main_supply,trade_pair.sub_supply)
            trade_pair.main_supply=bn.sub(trade_pair.main_supply,vol)
            trade_pair.sub_supply=bn.add(trade_pair.sub_supply,trade_amount)
        end
        assert(bn.compare(vol,"0") == 1,'amount error')
        chainhelper:transfer_from_caller(contract_base_info.owner, bn.toBigInteger(bn.mul(from_amount,math.pow(10,trade_pair.sub_unit))), trade_pair.sub_sym, true)
        chainhelper:transfer_from_owner(contract_base_info.caller, bn.toBigInteger(bn.mul(vol,math.pow(10,trade_pair.main_unit))), trade_pair.main_sym, true)

    end
    if(bn.compare(to_amount,"0") == 1) then
        assert( bn.compare(vol,to_amount),'slippage protection')
    end
    trade_pair.price=bn.div(trade_pair.main_supply,bn.mul(trade_pair.sub_supply,trade_pair.ratio))
    assert(bn.compare(trade_pair.main_supply,"0") == 1,'supply error')
    assert(bn.compare(trade_pair.sub_supply,"0") == 1,'supply error')
    assert( bn.compare(trade_pair.price,"0") == 1,'price error')
    public_data.pair_table[inx]=trade_pair
    local price_new = trade_pair.price
    chainhelper:write_chain()
    chainhelper:log('main_sym:'..trade_pair.main_sym..',sub_sym:'..trade_pair.sub_sym..',price_old:'..price_old..',price_new:'..price_new..',vol:'..vol)
end

--添加流动性
function add_liquidity(inx,main_amount,sub_amount)
    chainhelper:read_chain()
    local bn=import_contract(CONTRACT_BIGNUMBER)

    main_amount = bn.toDecimal(main_amount,10)
    sub_amount = bn.toDecimal(sub_amount,10)
    assert((bn.compare(main_amount,0) == 1) and (bn.compare(sub_amount,0) == 1), "invalid amount!")
    assert((bn.compare(main_amount,"1000000000") == -1) and (bn.compare(sub_amount,"1000000000") == -1) , "amount to big!")
    inx=tonumber(inx)
    assert(inx >0 , "invalid inx!")
    assert(public_data~=nil,'public_data is null')
    assert(public_data.pair_table~=nil,'pair_table is null')
    trade_pair = public_data.pair_table[inx]
    assert(trade_pair~=nil , "trade_pair not exists")
    assert(trade_pair.enable , "trade_pair not enable")
    liquid_table = private_data.liquid_table
    if(liquid_table==nil) then
        liquid_table={}
        private_data.liquid_table=liquid_table
    end
    liquid_pair = liquid_table[inx]
    if(liquid_pair==nil) then
        liquid_pair={}
        liquid_pair.share_keys="0"
        liquid_pair.main_mask="0"
        liquid_pair.sub_mask="0"
        liquid_pair.mine_mask="0"
        liquid_pair.main_amount=main_amount
        liquid_pair.sub_amount=sub_amount

        liquid_pair.main_draw="0"
        liquid_pair.sub_draw="0"
        liquid_pair.mine_draw="0"
        private_data.liquid_table[inx]=liquid_pair
    end


    if(trade_pair.type=='bancor') then
        --bancor模式只有抵押子币/抵押不影响supply值
        local share_keys=sub_amount
        trade_pair.share_keys=bn.add(trade_pair.share_keys,share_keys)
        liquid_pair.share_keys=bn.add(liquid_pair.share_keys,share_keys)
        liquid_pair.main_mask=bn.add(liquid_pair.main_mask,bn.mul(trade_pair.main_mask,share_keys))
        liquid_pair.sub_mask=bn.add(liquid_pair.sub_mask,bn.mul(trade_pair.sub_mask,share_keys))
        liquid_pair.main_amount=bn.add(liquid_pair.main_amount,main_amount)
        liquid_pair.sub_amount=bn.add(liquid_pair.sub_amount,sub_amount)
        chainhelper:transfer_from_caller(contract_base_info.owner,bn.toBigInteger(bn.mul(sub_amount,math.pow(10,trade_pair.sub_unit))), trade_pair.sub_sym, true)
    elseif (trade_pair.type=='swap') then
        --交换模式需要同时提供主币和子币，且影响supply值
        local main_supply=trade_pair.main_supply
        local sub_supply=trade_pair.sub_supply
        if(bn.compare(main_supply,"0")==0 and bn.compare(sub_supply,"0")==0) then
            main_supply=main_amount
            sub_supply=sub_amount
        else
            local rate = bn.div(trade_pair.main_supply,trade_pair.sub_supply)
            main_amount=bn.mul(sub_amount,rate)
            main_supply=bn.add(main_supply,main_amount)
            sub_supply=bn.add(sub_supply,sub_amount)
        end
        local share_keys=bn.mul(main_amount,sub_amount)
        trade_pair.share_keys=bn.add(trade_pair.share_keys,share_keys)
        trade_pair.main_supply=main_supply
        trade_pair.sub_supply=sub_supply
        liquid_pair.share_keys=bn.add(liquid_pair.share_keys,share_keys)
        liquid_pair.main_mask=bn.add(liquid_pair.main_mask,bn.mul(trade_pair.main_mask,share_keys))
        liquid_pair.sub_mask=bn.add(liquid_pair.sub_mask,bn.mul(trade_pair.sub_mask,share_keys))
        liquid_pair.main_amount=bn.add(liquid_pair.main_amount,main_amount)
        liquid_pair.sub_amount=bn.add(liquid_pair.sub_amount,sub_amount)
        chainhelper:transfer_from_caller(contract_base_info.owner, bn.toBigInteger(bn.mul(main_amount,math.pow(10,trade_pair.main_unit))), trade_pair.main_sym, true)
        chainhelper:transfer_from_caller(contract_base_info.owner, bn.toBigInteger(bn.mul(sub_amount,math.pow(10,trade_pair.sub_unit))), trade_pair.sub_sym, true)
    end
    public_data.pair_table[inx]=trade_pair
    private_data.liquid_table[inx]=liquid_pair
    chainhelper:write_chain()
end





--提取做市手续费收益
function draw_liquid_fee(inx)
    chainhelper:read_chain()
    local bn=import_contract(CONTRACT_BIGNUMBER)

    assert(public_data.pair_table ~= nil,"pair_table not found!")
    local trade_pair = public_data.pair_table[inx]
    assert(trade_pair ~= nil,"trade_pair not found!")

    assert(private_data.liquid_table ~= nil,"liquid_table not found!")
    local liquid_pair = private_data.liquid_table[inx]
    assert(liquid_pair ~= nil,"liquid_pair not found!")

    local main_profit = bn.sub(bn.mul(trade_pair.main_mask,liquid_pair.share_keys),liquid_pair.main_mask)
    local sub_profit = bn.sub(bn.mul(trade_pair.sub_mask,liquid_pair.share_keys),liquid_pair.sub_mask)

    main_profit=bn.toDecimal(main_profit,trade_pair.main_unit)
    sub_profit=bn.toDecimal(sub_profit,trade_pair.sub_unit)

    if(bn.compare(main_profit,"0")==1) then
        liquid_pair.main_mask=bn.mul(trade_pair.main_mask,liquid_pair.share_keys)
        liquid_pair.main_draw = bn.add(liquid_pair.main_draw,main_profit)

    end

    if(bn.compare(main_profit,"0")==1) then
        liquid_pair.main_mask=bn.mul(trade_pair.main_mask,liquid_pair.share_keys)
        liquid_pair.main_draw = bn.add(liquid_pair.main_draw,main_profit)
        chainhelper:transfer_from_owner(contract_base_info.caller, bn.toBigInteger(bn.mul(main_amount,math.pow(10,trade_pair.main_unit))), trade_pair.main_sym, true)
    end

    if(bn.compare(sub_profit,"0")==1) then
        liquid_pair.sub_mask=bn.mul(trade_pair.sub_mask,liquid_pair.share_keys)
        liquid_pair.sub_draw = bn.add(liquid_pair.sub_draw,sub_profit)
        chainhelper:transfer_from_owner(contract_base_info.caller, bn.toBigInteger(bn.mul(sub_amount,math.pow(10,trade_pair.sub_unit))), trade_pair.sub_sym, true)
    end
    public_data.pair_table[inx]=trade_pair
    private_data.liquid_table[inx]=liquid_pair
    chainhelper:write_chain()
end

--提取做市挖矿收益
function draw_liquid_mine(inx)

end

--提取做市凭证
function draw_liquid_key(inx,keys)
    draw_liquid_fee(inx)
    chainhelper:read_chain()
    local bn=import_contract(CONTRACT_BIGNUMBER)

    assert(public_data.pair_table ~= nil,"pair_table not found!")
    local trade_pair = public_data.pair_table[inx]
    assert(trade_pair ~= nil,"trade_pair not found!")

    assert(private_data.liquid_table ~= nil,"liquid_table not found!")
    local liquid_pair = private_data.liquid_table[inx]
    assert(liquid_pair ~= nil,"liquid_pair not found!")

    assert(bn.compare(keys,"0")==1,"keys must positive")
    local trade_share_keys=bn.sub(trade_pair.share_keys,keys)
    local liquid_share_keys=bn.sub(liquid_pair.share_keys,keys)
    assert(bn.compare(trade_share_keys,"0")>=0,"pair keys not enough!")
    assert(bn.compare(liquid_share_keys,"0")>=0,"user keys not enough!")

    trade_pair.share_keys=trade_share_keys
    liquid_pair.share_keys=liquid_share_keys
    liquid_pair.main_mask=bn.mul(trade_pair.main_mask,liquid_pair.share_keys)
    liquid_pair.sub_mask=bn.mul(trade_pair.sub_mask,liquid_pair.share_keys)

    public_data.pair_table[inx]=trade_pair
    private_data.liquid_table[inx]=liquid_pair
    chainhelper:write_chain()
end


--抵押平台币
function stake_platform(amount)
    chainhelper:read_chain()
    local bn=import_contract(CONTRACT_BIGNUMBER)
    amount = bn.toDecimal(amount,10)
    assert((bn.compare(amount,0) == 1), "invalid amount!")
    assert((bn.compare(amount,"1000000000") == -1), "amount to big!")

    public_data.platform_table.share_keys=bn.add(public_data.platform_table.share_keys,amount)
    local platform_table = private_data.platform_table
    if(platform_table== nil) then
        platform_table={}
        platform_table.share_keys="0"
        platform_table.list={}
    end
    platform_table.share_keys=bn.add(platform_table.share_keys,amount)
    for i, v in pairs(public_data.platform_table.list) do
        if(platform_table.list[i]==nil) then
            platform_table.list[i]={}
            platform_table.list[i].share_mask=bn.mul(amount,v.share_mask)
        else
            platform_table.list[i].share_mask=bn.add(platform_table.list[i].share_mask,bn.mul(amount,v.share_mask))
        end
    end
    private_data.platform_table=platform_table
    chainhelper:transfer_from_caller(contract_base_info.owner, bn.toBigInteger(bn.mul(main_amount,math.pow(10,trade_pair.main_unit))), trade_pair.main_sym, true)
    chainhelper:write_chain()
end

--提取抵押手续费收益
function draw_stake_fee_profit()

end




