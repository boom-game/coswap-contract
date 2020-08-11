
local DEV_RATE = 0.5

-- main_supply 主币储备量
-- sub_supply 子币发行量
-- ratio 系数
function add_pair(ratio,main_supply,main_sym,main_unit,main_fee, sub_supply,sub_sym,sub_unit,sub_fee)
    assert(chainhelper:is_owner(),'no auth')
    chainhelper:read_chain()
    if public_data == nil then 
        public_data = {}
    end
    bancor_table = public_data.bancor_table
    if bancor_table == nil then 
        bancor_table = {}
        public_data.bancor_table = bancor_table
    end
    for inx,trade_pair in pairs(bancor_table) do
        if(trade_pair.main_sym==main_sym and trade_pair.sub_sym==sub_sym) then
            assert(false,'pair already exists')
        end
        if(trade_pair.main_sym==sub_sym and trade_pair.sub_sym==main_sym) then
            assert(false,'pair already exists')
        end
    end
    trade_pair = {}
    trade_pair.ratio=ratio
    trade_pair.price=main_supply/(sub_supply*ratio)

    trade_pair.main_supply=main_supply
    trade_pair.main_sym=main_sym
    trade_pair.main_unit=main_unit
    trade_pair.main_fee=main_fee

    trade_pair.sub_supply=sub_supply
    trade_pair.sub_sym=sub_sym
    trade_pair.sub_unit=sub_unit
    trade_pair.sub_fee=sub_fee

    trade_pair.main_keys=0
    trade_pair.main_mask=0
    trade_pair.sub_keys=0
    trade_pair.sub_mask=0

    table.insert(public_data.bancor_table, trade_pair)
    chainhelper:write_chain()
end

function rm_pair(inx)
    assert(chainhelper:is_owner(),'no auth')
    chainhelper:read_chain()
    assert(public_data~=nil,'public_data is null')
    assert(public_data.bancor_table~=nil,'bancor_table is null')
    table.remove(public_data.bancor_table, inx)
    chainhelper:write_chain()
end

function reset()
    assert(chainhelper:is_owner(),'no auth')
    chainhelper:read_chain()
    public_data={}
    chainhelper:write_chain()
end

--交换
function swap_pair(inx,amount,from_sym,to_sym)

    amount=tonumber(amount)
    assert(amount >0 , "invalid amount!") 
    assert(amount <= 1000000000 , "invalid amount!") 
    assert(inx >0 , "invalid inx!") 
    chainhelper:read_chain()
    assert(public_data~=nil,'public_data is null')
    assert(public_data.bancor_table~=nil,'bancor_table is null')
    trade_pair = public_data.bancor_table[inx]
    assert(trade_pair~=nil , "trade_pair not exists") 
    is_buy=(trade_pair.main_sym==from_sym and trade_pair.sub_sym==to_sym)
    is_sell=(trade_pair.main_sym==to_sym and trade_pair.sub_sym==from_sym)
    assert((is_buy or is_sell),"trade_pair not exists") 
    local price_old = trade_pair.price
    local vol=0;
    
    if(is_buy) then
        local fee = amount*trade_pair.main_fee
        local dev_fee=fee*DEV_RATE
        local share_fee=fee-dev_fee
        amount = amount - fee
        --开发费用
        if(dev_fee>0) then
            chainhelper:transfer_from_caller('coswap-fund', dev_fee*trade_pair.main_unit, trade_pair.main_sym, true)
        end
        --分成金额
        if(share_fee>0 and trade_pair.main_keys>0){
            local profit_per_key=share_fee / trade_pair.main_keys
            trade_pair.main_mask=trade_pair.main_mask+profit_per_key
        }
        --交换代币
        local s = (math.pow((1 + amount/trade_pair.main_supply),trade_pair.ratio)-1)*trade_pair.sub_supply
        assert(s>0,'amount error')
        trade_pair.main_supply=trade_pair.main_supply+amount
        trade_pair.sub_supply=trade_pair.sub_supply+s
        chainhelper:transfer_from_caller(contract_base_info.owner, amount*trade_pair.main_unit, trade_pair.main_sym, true)
        chainhelper:transfer_from_owner(contract_base_info.caller, s*trade_pair.sub_unit, trade_pair.sub_sym, true)
        vol = amount;
    elseif(is_sell) then
        local fee = amount*trade_pair.sub_fee
        local dev_fee=fee*DEV_RATE
        local share_fee=fee-dev_fee
        amount = amount - fee
        --开发费用
        if(dev_fee>0) then
            chainhelper:transfer_from_caller('coswap-fund', dev_fee*trade_pair.sub_unit, trade_pair.sub_sym, true)
        end
        --分成金额
        if(share_fee>0 and trade_pair.sub_keys>0){
            local profit_per_key=share_fee / trade_pair.sub_keys
            trade_pair.sub_mask=trade_pair.sub_mask+profit_per_key
        }
        --交换代币
        local m = (1-math.pow((1 - amount/trade_pair.sub_supply),(1/ratio)))*trade_pair.main_supply
        assert(m>0,'amount error')
        trade_pair.main_supply=trade_pair.main_supply-m
        trade_pair.sub_supply=trade_pair.sub_supply-amount
        chainhelper:transfer_from_caller(contract_base_info.owner, amount*trade_pair.sub_unit, trade_pair.sub_sym, true)
        chainhelper:transfer_from_owner(contract_base_info.caller, m*trade_pair.main_unit, trade_pair.main_sym, true)
        vol = m;
    end
    trade_pair.price=trade_pair.main_supply/(trade_pair.sub_supply*trade_pair.ratio)
    assert(trade_pair.main_supply>0,'supply error')
    assert(trade_pair.sub_supply>0,'supply error')
    assert(trade_pair.price>0,'price error')
    public_data.bancor_table[inx]=trade_pair
    local price_new = trade_pair.price
    chainhelper:write_chain()
    chainhelper:log('main_sym:'..trade_pair.main_sym..',sub_sym:'..trade_pair.sub_sym..',price_old:'..price_old..',price_new:'..price_new..',vol:'..vol)
end


--质押
function delegate(inx,amount)
    amount=tonumber(amount)
    assert(amount >0 , "invalid amount!") 
    assert(amount <= 1000000000 , "invalid amount!") 
    assert(inx >0 , "invalid inx!") 
    chainhelper:read_chain()
    assert(public_data~=nil,'public_data is null')
    assert(public_data.bancor_table~=nil,'bancor_table is null')
    trade_pair = public_data.bancor_table[inx]
    assert(trade_pair~=nil , "trade_pair not exists") 
    chainhelper:transfer_from_caller(contract_base_info.owner, amount*trade_pair.sub_unit, trade_pair.sub_sym, true)

    bancor_share_table = private_data.bancor_share_table
    if bancor_share_table == nil then 
        bancor_share_table = {}
        private_data.bancor_share_table = bancor_share_table
    end
    share_pair = private_data.bancor_share_table[inx]
    if share_pair == nil then
        share_pair={}
        share_pair.main_sym=main_sym
        share_pair.sub_sym=sub_sym    
        share_pair.main_keys=0
        share_pair.main_mask=0
        share_pair.sub_keys=0
        share_pair.sub_mask=0
        private_data.bancor_share_table[inx]=share_pair
    end
    trade_pair.main_keys=trade_pair.main_keys+amount
    share_pair.main_keys=share_pair.main_keys+amount
    share_pair.main_mask=share_pair.main_mask+(trade_pair.main_mask*amount)

    trade_pair.sub_keys=trade_pair.sub_keys+amount
    share_pair.sub_keys=share_pair.sub_keys+amount
    share_pair.sub_mask=share_pair.sub_mask+(trade_pair.sub_mask*amount)

    private_data.bancor_share_table[inx]=share_pair
    public_data.bancor_table[inx]=trade_pair
    chainhelper:write_chain()
end

--计算分成
function cal_profit(inx)
    assert(inx >0 , "invalid inx!") 
    chainhelper:read_chain()
    assert(public_data~=nil,'public_data is null')
    assert(public_data.bancor_table~=nil,'bancor_table is null')
    trade_pair = public_data.bancor_table[inx]
    assert(trade_pair~=nil , "trade_pair not exists") 

    assert(private_data~=nil,'private_data is null')
    assert(private_data.bancor_share_table~=nil,'bancor_share_table is null')
    share_pair=private_data.bancor_share_table[inx]
    assert(share_pair~=nil , "share_pair not exists") 

    local main_profit = trade_pair.main_mask * share_pair.main_keys - share_pair.main_mask
    local sub_profit = trade_pair.sub_mask * share_pair.sub_keys - share_pair.sub_mask

    chainhelper:log('main_sym:'..trade_pair.main_sym..',sub_sym:'..trade_pair.sub_sym..',main_profit:'..main_profit..',sub_profit:'..sub_profit)
end

--提取收益
function withdraw_profit(inx)
    assert(inx >0 , "invalid inx!") 
    chainhelper:read_chain()
    assert(public_data~=nil,'public_data is null')
    assert(public_data.bancor_table~=nil,'bancor_table is null')
    trade_pair = public_data.bancor_table[inx]
    assert(trade_pair~=nil , "trade_pair not exists") 

    assert(private_data~=nil,'private_data is null')
    assert(private_data.bancor_share_table~=nil,'bancor_share_table is null')
    share_pair=private_data.bancor_share_table[inx]
    assert(share_pair~=nil , "share_pair not exists") 

    local main_profit = trade_pair.main_mask * share_pair.main_keys - share_pair.main_mask
    local sub_profit = trade_pair.sub_mask * share_pair.sub_keys - share_pair.sub_mask

    chainhelper:transfer_from_owner(contract_base_info.caller, main_profit*trade_pair.main_unit, trade_pair.main_sym, true)
    chainhelper:transfer_from_owner(contract_base_info.caller, sub_profit*trade_pair.sub_unit, trade_pair.sub_sym, true)

    share_pair.main_mask=trade_pair.main_mask * share_pair.main_keys
    share_pair.sub_mask=trade_pair.sub_mask * share_pair.sub_keys

    private_data.bancor_share_table[inx]=share_pair
    public_data.bancor_table[inx]=trade_pair
    chainhelper:write_chain()

    chainhelper:log('main_sym:'..trade_pair.main_sym..',sub_sym:'..trade_pair.sub_sym..',main_profit:'..main_profit..',sub_profit:'..sub_profit)
end

--赎回
function undelegate(inx)
    assert(inx >0 , "invalid inx!") 
    chainhelper:read_chain()
    assert(public_data~=nil,'public_data is null')
    assert(public_data.bancor_table~=nil,'bancor_table is null')
    trade_pair = public_data.bancor_table[inx]
    assert(trade_pair~=nil , "trade_pair not exists") 

    assert(private_data~=nil,'private_data is null')
    assert(private_data.bancor_share_table~=nil,'bancor_share_table is null')
    share_pair=private_data.bancor_share_table[inx]
    assert(share_pair~=nil , "share_pair not exists") 

    local main_profit = trade_pair.main_mask * share_pair.main_keys - share_pair.main_mask
    local sub_profit = trade_pair.sub_mask * share_pair.sub_keys - share_pair.sub_mask

    chainhelper:transfer_from_owner(contract_base_info.caller, main_profit*trade_pair.main_unit, trade_pair.main_sym, true)
    chainhelper:transfer_from_owner(contract_base_info.caller, sub_profit*trade_pair.sub_unit, trade_pair.sub_sym, true)
    chainhelper:transfer_from_owner(contract_base_info.caller, share_pair.sub_keys*trade_pair.sub_unit, trade_pair.sub_sym, true)
    trade_pair.main_keys=trade_pair.main_keys-share_pair.main_keys
    trade_pair.sub_keys=trade_pair.sub_keys-share_pair.sub_keys
    private_data.bancor_share_table[inx]=nil
    public_data.bancor_table[inx]=trade_pair
    chainhelper:write_chain()
    chainhelper:log('main_sym:'..trade_pair.main_sym..',sub_sym:'..trade_pair.sub_sym..',main_profit:'..main_profit..',sub_profit:'..sub_profit)
end


