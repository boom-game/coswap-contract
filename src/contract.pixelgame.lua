--local PIX_WV="PTEST"
--local PIX_WV="PIXTEST"
local PIX_WV="PIX"

local pro_start_time=1601622000

local CONTRACT_BIGNUMBER = "contract.bignum"
local bn=nil

local FUND_ACCOUNT = "coswap-fund"

local function _regbn()
    if(bn==nil) then
        bn=import_contract(CONTRACT_BIGNUMBER)
    end
end

local function _check_start()
    regbn()
    local now_time_sec=math.floor(chainhelper:time())
    assert(now_time_sec>pro_start_time,'2020年10月02日晚15点整开始')
end


function resetPix(nft_id)
    assert(chainhelper:is_owner(), "owner only")
    local describe1 = {
        c = '#ffffff',
        p = "1.00000",
        u = "1.2.1251196"
    }
    local describe2 = {
        c = '#ffffff',
        p = "10.00000",
        u = "1.2.1251196"
    }
    local describe3 = {
        c = '#ffffff',
        p = "0.10000",
        u = "1.2.1251196"
    }
    chainhelper:change_nht_active_by_owner(contract_base_info.caller,nft_id,true)
    chainhelper:nht_describe_change(nft_id, "coco", cjson.encode(describe1), true)
    chainhelper:nht_describe_change(nft_id, "cocos", cjson.encode(describe2), true)
    chainhelper:nht_describe_change(nft_id, "cfs", cjson.encode(describe3), true)
    chainhelper:nht_describe_change(nft_id, "kkkk", cjson.encode(describe3), true)
    chainhelper:change_nht_active_by_owner(contract_base_info.owner,nft_id,true)
end

function forceUpdatePixel(nft_id,user,coin,color,price)
    assert(chainhelper:is_owner(), "owner only")
    assert(coin ~= nil and nft_id ~= nil and color ~= nil and price ~= nil and user ~= nil,'param invalidate')
    assert(coin=='coco' or coin=='cocos' or coin=='cfs' or coin=='kkkk','coin not support')
    local tcolor = string.match(color, "#%x+")
    assert(tcolor == color,"color invalidate")
    assert(string.len(tcolor) == 7 or string.len(tcolor) == 9,"color invalidate")
    local describe = {
        c = color,
        p = price,
        u = user
    }
    chainhelper:nht_describe_change(nft_id, coin, cjson.encode(describe), true)
end


local function _updatePixel(nft_id,user,coin,x,y,color)
    assert(coin ~= nil and nft_id ~= nil and color ~= nil and user ~= nil,'param invalidate')
    assert(coin=='coco' or coin=='cocos' or coin=='cfs' or coin=='kkkk','coin not support')
    local tcolor = string.match(color, "#%x+")
    assert(tcolor == color,"color invalidate")
    assert(string.len(tcolor) == 7 or string.len(tcolor) == 9,"color invalidate")

    local pixelNft = cjson.decode(chainhelper:get_nft_asset(nft_id))
    local baseDescribe = cjson.decode(pixelNft.base_describe)
    assert(pixelNft.world_view == PIX_WV,"world view not match")
    assert(pixelNft.nh_asset_creator == contract_base_info.owner,"nft creator error")
    assert(pixelNft.nh_asset_owner == contract_base_info.owner,"nft owner error")

    assert(baseDescribe.x == x,"x not match")
    assert(baseDescribe.y == y,"y not match")

    local costData={
        coin = coin,
        amount = 0
    }

    local coinData=nil
    for _, contract in pairs(pixelNft.describe_with_contract) do
        if contract[1] == contract_base_info.id then
            for _, describe in pairs(contract[2]) do
                if describe[1] == coin then
                    coinData = cjson.decode(describe[2])
                    break
                end
            end
            break
        end
    end

    local oldPrice=coinData.p
    local newPrice=oldPrice
    local oldUser=coinData.u

    if(oldUser~=user) then
        costData.amount=oldPrice
        newPrice=oldPrice*1.3
    end

    local describe = {
        c = color,
        p = newPrice,
        u = user
    }
    chainhelper:change_nht_active_by_owner(user,nft_id,true)
    chainhelper:nht_describe_change(nft_id, coin, cjson.encode(describe), true)
    chainhelper:change_nht_active_by_owner(contract_base_info.owner,nft_id,true)
    return costData
end



function buyPixels(user,refer,pjson)
    assert(false,"升级维护中...")
    assert(user ~= nil and string.len(user) > 1,'user not validate')
    --assert(refer ~= nil and string.len(refer) > 1,'refer not validate')
    local pixels=cjson.decode(pjson)
    assert(#pixels > 0,'pix size is 0')
    --local user = contract_base_info.caller
    local totalCostAmount = 0
    for i, v in pairs(pixels) do
        local costData = _updatePixel(v.nft_id,user,v.coin,v.x,v.y,v.color)
        totalCostAmount=totalCostAmount+costData.amount
    end
    chainhelper:log(totalCostAmount)
end





