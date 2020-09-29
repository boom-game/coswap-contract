
--测试合约
--local MAIN_CONTRACT = "1.16.166"

--正式合约
local MAIN_CONTRACT = "1.16.138"

function safe_transfer_from_owner(to,amount,sym,log)
    chainhelper:read_chain()
    assert(contract_base_info.invoker_contract_id == MAIN_CONTRACT,
            "only called by main contract")
    local lock_sym_list=public_data.lock_sym_list
    if(lock_sym_list~=nil and lock_sym_list[sym]~=nil) then
        if(lock_sym_list[sym].lock == true) then
            chainhelper:adjust_lock_asset(sym, -amount)
            lock_sym_list[sym].amount=lock_sym_list[sym].amount-amount
            public_data.lock_sym_list=lock_sym_list
        end
    end
    chainhelper:log('to:'..to..',amount:'..amount..',sym:'..sym)
    chainhelper:write_chain()
end

function safe_transfer_from_caller(to,amount,sym,log)
    chainhelper:read_chain()
    assert(contract_base_info.invoker_contract_id == MAIN_CONTRACT,
            "only called by main contract")

    chainhelper:log('to:'..to..',amount:'..amount..',sym:'..sym)
    local lock_sym_list=public_data.lock_sym_list
    if(lock_sym_list~=nil and lock_sym_list[sym]~=nil) then
        if(lock_sym_list[sym].lock == true) then
            chainhelper:adjust_lock_asset(sym, amount)
            lock_sym_list[sym].amount=lock_sym_list[sym].amount+amount
            public_data.lock_sym_list=lock_sym_list
        end
    end
    chainhelper:write_chain()
end

function must_error(b)
    assert(1==b,'error!')
end


function admin_lock(sym)
    assert(chainhelper:is_owner(),'no auth')
    chainhelper:read_chain()
    sym=tostring(sym)
    local lock_sym_list=public_data.lock_sym_list
    if(lock_sym_list==nil) then
        lock_sym_list={}
    end
    if(lock_sym_list[sym]==nil) then
        lock_sym_list[sym]={}
    end
    local total_amount = chainhelper:get_account_balance(contract_base_info.owner,sym)
    chainhelper:adjust_lock_asset(sym,total_amount)
    lock_sym_list[sym].lock=true
    lock_sym_list[sym].amount=total_amount
    public_data.lock_sym_list=lock_sym_list
    chainhelper:write_chain()
end

function admin_unlock(sym)
    assert(chainhelper:is_owner(),'no auth')
    chainhelper:read_chain()
    sym=tostring(sym)
    local lock_sym_list=public_data.lock_sym_list
    lock_sym_list[sym].lock=false
    local total_amount = lock_sym_list[sym].amount
    chainhelper:adjust_lock_asset(sym,-total_amount)
    public_data.lock_sym_list=lock_sym_list
    chainhelper:write_chain()
end

function force_unlock(sym,amount)
    assert(chainhelper:is_owner(),'no auth')
    chainhelper:read_chain()
    sym=tostring(sym)
    amount=tonumber(amount)
    assert(amount<0,'amount must neg')
    local lock_sym_list=public_data.lock_sym_list
    if(lock_sym_list~=nil and lock_sym_list[sym]~=nil) then
        lock_sym_list[sym]=nil
        public_data.lock_sym_list=lock_sym_list
    end
    chainhelper:adjust_lock_asset(sym,amount)
    chainhelper:write_chain()
end

function force_unlock2(sym)
    assert(chainhelper:is_owner(),'no auth')
    chainhelper:read_chain()
    sym=tostring(sym)
    amount=tonumber(amount)
    assert(amount<0,'amount must neg')
    local lock_sym_list=public_data.lock_sym_list
    if(lock_sym_list~=nil and lock_sym_list[sym]~=nil) then
        lock_sym_list[sym]=nil
        public_data.lock_sym_list=lock_sym_list
    end
    local total_amount = chainhelper:get_account_balance(contract_base_info.owner,sym)
    chainhelper:adjust_lock_asset(sym,-total_amount)
    chainhelper:write_chain()
end