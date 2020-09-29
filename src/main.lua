
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


local haha={}
for i = 1, 10 do
    haha[i*2]=i
end

for i, v in pairs(haha) do
    haha[i]=nil
end

haha[4] = nil

local a= "a"

