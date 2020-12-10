--local PIX_WV="PTEST"
--local PIX_WV="PIXTEST"
local PIX_WV="PIX"
local FUND_ACCOUNT = "coswap-fund"

function createPix(x,y)
    assert(chainhelper:is_owner(), "owner only")
    x=tonumber(x)
    y=tonumber(y)
    local describe = {
        x = x,
        y = y,
    }
    local pair_id = chainhelper:create_nft_asset(contract_base_info.owner,
            PIX_WV, cjson.encode(describe), true, true)
    resetPix(pair_id);

end


function resetPix(nft_id)
    assert(chainhelper:is_owner(), "owner only")
    local describe = {
        c = '#ffffff',
        p = "1",
        u = "1.2.1251196"
    }
    chainhelper:nht_describe_change(nft_id, "coco", cjson.encode(describe), true)
    chainhelper:nht_describe_change(nft_id, "cocos", cjson.encode(describe), true)
    chainhelper:nht_describe_change(nft_id, "cfs", cjson.encode(describe), true)
    chainhelper:nht_describe_change(nft_id, "kkkk", cjson.encode(describe), true)
end



function reset()
    assert(chainhelper:is_owner(), "owner only")
    chainhelper:read_chain()
    public_data.lx = 0
    public_data.ly = -1
    chainhelper:write_chain()
end

function createNft(size)
    chainhelper:read_chain()
    size=tonumber(size)
    local lx=public_data.lx or 0
    local ly=public_data.ly or -1

    for i = 1, size do
        ly=ly+1
        if(ly>999) then
            ly=0
            lx=lx+1
            if(lx>999) then
                assert(false,"create end")
            end
        end
        createPix(lx,ly)
        public_data.lx=lx
        public_data.ly=ly
    end

    chainhelper:write_chain()
end