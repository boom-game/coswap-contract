local bn={}
bn.add=function(a,b)
    local ret= a+b
    return ret
end
bn.sub=function(a,b)
    return a-b
end
bn.mul=function(a,b)
    return a*b
end
bn.div=function(a,b)
    return a/b
end


local start_time=1600776002
local now_time=1601819912
--local now_time=1601819912
--local now_time = 1601784000
--local now_time = 1601780400
--local now_time = 1601778600
local BLOCK_CUT=1209600


local public_data={}
public_data.last_mine_time=1600776002
public_data.last_block_num=0
public_data.last_mine_award=0

local cut_rate = 0.9



function tick_mine(nowtime)
    local last_mine_time = math.floor(public_data.last_mine_time)
    local last_block_num = math.floor(public_data.last_block_num)
    local last_mine_award = public_data.last_mine_award
    --local fly_time = nowtime - last_mine_time
    local fly_time = nowtime-last_mine_time
    local fly_block = fly_time * 2
    if (last_mine_time > 0 and fly_block > 0) then
        local total_block = fly_block + last_block_num
        local old_cut_times=math.floor(last_block_num / BLOCK_CUT)
        local now_cut_times = math.floor(total_block / BLOCK_CUT)
        local extra_block = total_block - now_cut_times * BLOCK_CUT
        local now_rate = 1
        local init_award = 1
        local now_mine_award = 0
        for i = 1, old_cut_times do
            now_rate = bn.mul(now_rate, cut_rate)
        end

        if(now_cut_times>old_cut_times) then
            local fly_cnt=now_cut_times-old_cut_times
            local head_block=(old_cut_times+1)*BLOCK_CUT-last_block_num
            now_mine_award=bn.add(now_mine_award,bn.mul(init_award,bn.mul(head_block,now_rate)))
            local tail_cnt=fly_cnt-1
            if(tail_cnt > 0) then
                for i = 1, tail_cnt do
                    now_rate = bn.mul(now_rate, cut_rate)
                    now_mine_award = bn.add(now_mine_award, bn.mul(init_award, bn.mul(BLOCK_CUT, now_rate)))
                end
            end
            if (extra_block > 0) then
                now_rate = bn.mul(now_rate, cut_rate)
                now_mine_award = bn.add(now_mine_award, bn.mul(extra_block, now_rate))
            end
        else
            now_mine_award=bn.add(now_mine_award,bn.mul(init_award,bn.mul(fly_block,now_rate)))
        end
        local total_mine_award = bn.add(now_mine_award, last_mine_award)
        public_data.last_block_num=total_block
        public_data.last_mine_time=nowtime
        public_data.last_mine_award=total_mine_award
        local a=""
    end

end

tick_mine(1601819912)
tick_mine(1601868870)
cut_rate=0.8
tick_mine(1602077919)

