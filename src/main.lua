
array = {}
for i=1,3 do
    array[i] = {}
    for j=1,3 do
        array[i][j] = i*j
    end
end

local ret = math.floor(2100/524)
ret=ret%2







local queue = {}

function add()
    local rd={}
    rd.user=math.random(1,100)
    rd.amount=math.random(1,100)
    table.insert(queue,rd)
    local size=#queue
    if(size>5) then
        table.remove(queue,1)
    end
end

for i = 1, 20 do
    add()
    local a=""
end




local BLOCK_CUT=1209600

local total_block = 1209700
local cut_times = math.floor(total_block / BLOCK_CUT)
local extra_block = total_block - cut_times * BLOCK_CUT
local cut_rate = 0.9
local now_rate = 1
local init_award = 1
local total_mine_award = "0"
for i = 1, cut_times do
    total_mine_award=total_mine_award+ BLOCK_CUT*now_rate*init_award
    now_rate = now_rate*cut_rate
end

if (extra_block > 0) then
    total_mine_award = total_mine_award+extra_block*now_rate
end
local ta=total_mine_award
local a=""
