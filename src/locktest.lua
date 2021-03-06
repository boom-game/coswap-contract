---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liyunhan.
--- DateTime: 2020/9/26 6:55 PM
---


function lock_test(amount)
    assert(chainhelper:is_owner(), "owner only")
    chainhelper:adjust_lock_asset("COCOS", amount)
end



function lock_test(amount)
    assert(chainhelper:is_owner(), "owner only")
    chainhelper:adjust_lock_asset("COCOS", amount)
end





local function _safe_transfer_from_owner(to,amount,sym,log)
    chainhelper:read_chain()

    local lock_sym_list=public_data.lock_sym_list
    if(lock_sym_list~=nil and lock_sym_list[sym]~=nil) then
        if(lock_sym_list[sym].lock == true) then
            chainhelper:adjust_lock_asset(sym, -amount)
            lock_sym_list[sym].amount=lock_sym_list[sym].amount-amount
            public_data.lock_sym_list=lock_sym_list
        end
    end
    chainhelper:transfer_from_owner(to, amount, sym, log)
    chainhelper:write_chain()
end

local function _safe_transfer_from_caller(to,amount,sym,log)
    chainhelper:read_chain()
    chainhelper:transfer_from_caller(to, amount, sym, log)
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


function admin_lock(sym)
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

function transfer_test1()
    assert(chainhelper:is_owner(), "owner only")
    local amount1=100000;
    local amount2=2000000;
    local amount3=4000000;
    _safe_transfer_from_owner('boxtest2', amount1, 'COCOS', true)
    _safe_transfer_from_owner('boxtest2', amount2, 'COCOS', true)
    _safe_transfer_from_owner('boxtest3', amount3, 'COCOS', true)
end

function transfer_test2()
    assert(chainhelper:is_owner(), "owner only")
    local amount1=100000;
    local amount2=2000000;
    local amount3=4000000;
    _safe_transfer_from_caller(contract_base_info.owner, amount1, 'COCOS', true)
    _safe_transfer_from_owner('boxtest2', amount2, 'COCOS', true)
    _safe_transfer_from_caller(contract_base_info.owner, amount3, 'COCOS', true)
    _safe_transfer_from_owner('boxtest3', amount3, 'COCOS', true)
end