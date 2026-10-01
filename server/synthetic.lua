local B = SzCoreBench

local JOBS = { 'unemployed', 'police', 'ambulance', 'mechanic', 'taxi', 'cardealer', 'realestate' }
local ITEMS = { 'water', 'sandwich', 'phone', 'bandage', 'radio', 'repairkit', 'lockpick', 'cash_bundle' }

local function makeDataset(n)
    collectgarbage('collect')
    local before = collectgarbage('count')
    local d = { players = {}, bySource = {}, byCitizen = {}, byLicense = {}, jobIndex = {}, jobCounts = {}, dutyJobCounts = {}, dirty = {}, callbacks = {}, hooks = {}, queue = {} }
    for _, job in ipairs(JOBS) do d.jobIndex[job] = {}; d.jobCounts[job] = 0; d.dutyJobCounts[job] = 0 end
    for i = 1, n do
        local job = JOBS[(i % #JOBS) + 1]
        local duty = (i % 3) ~= 0
        local citizen = ('BENCH%08d'):format(i)
        local license = ('license:bench%08d'):format(i)
        local inv = {}
        for slot = 1, 12 do inv[slot] = { name = ITEMS[((i + slot) % #ITEMS) + 1], amount = ((i + slot) % 5) + 1 } end
        local p = {source=i,citizenid=citizen,license=license,job={name=job,grade=i%6,duty=duty},money={cash=2500+i,bank=15000+i,crypto=i%1000},metadata={hunger=100-(i%70),thirst=100-(i%65),stress=i%100},permissions={['player.basic']=true,['bench.read']=true},inventory=inv}
        d.players[#d.players+1]=p;d.bySource[i]=p;d.byCitizen[citizen]=i;d.byLicense[license]=i;d.jobIndex[job][i]=true;d.jobCounts[job]=d.jobCounts[job]+1
        if duty then d.dutyJobCounts[job]=d.dutyJobCounts[job]+1 end
        d.queue[i]={id=i,priority=(i*37)%1000,joined=i};if i%10==0 then d.dirty[i]=true end;if i%5000==0 then Wait(0)end
    end
    for i=1,64 do d.callbacks['bench:cb:'..i]=function(x)return x+i end end
    for i=1,8 do d.hooks[i]=function(ctx)ctx.value=ctx.value+i end end
    collectgarbage('collect');d.memoryKb=collectgarbage('count')-before;return d
end

function B.runSynthetic(virtualPlayers, iterations, rounds)
    local d=makeDataset(virtualPlayers);local target=math.max(1,math.floor(virtualPlayers*.73));local p=d.bySource[target];local targetJob=p.job.name
    local scanIterations=math.max(50,math.min(1000,math.floor(iterations/100)));local jsonIterations=math.max(100,math.min(5000,math.floor(iterations/20)));local batchIterations=math.max(20,math.min(250,math.floor(iterations/500)));local queueIterations=math.max(20,math.min(200,math.floor(iterations/1000)));local encoded=json.encode(p);local tests={}
    tests[#tests+1]=B.measure('source_direct_lookup',iterations,rounds,function()return d.bySource[target]end)
    tests[#tests+1]=B.measure('citizen_index_lookup',iterations,rounds,function()local s=d.byCitizen[p.citizenid];return d.bySource[s]end)
    tests[#tests+1]=B.measure('license_index_lookup',iterations,rounds,function()local s=d.byLicense[p.license];return d.bySource[s]end)
    tests[#tests+1]=B.measure('job_count_cached',iterations,rounds,function()return d.jobCounts[targetJob]end)
    tests[#tests+1]=B.measure('duty_job_count_cached',iterations,rounds,function()return d.dutyJobCounts[targetJob]end)
    tests[#tests+1]=B.measure('job_index_set_fetch',iterations,rounds,function()return d.jobIndex[targetJob]end)
    tests[#tests+1]=B.measure('job_full_scan',scanIterations,rounds,function()local n=0;for i=1,#d.players do if d.players[i].job.name==targetJob then n=n+1 end end;return n end,{note=('scan of %d virtual players'):format(virtualPlayers)})
    tests[#tests+1]=B.measure('permission_lookup',iterations,rounds,function()return p.permissions['bench.read']==true end)
    tests[#tests+1]=B.measure('metadata_read',iterations,rounds,function()return p.metadata.hunger end)
    tests[#tests+1]=B.measure('metadata_write_restore',iterations,rounds,function(i)local old=p.metadata.stress;p.metadata.stress=i%100;p.metadata.stress=old;return old end)
    tests[#tests+1]=B.measure('money_add_remove',iterations,rounds,function()p.money.bank=p.money.bank+1;p.money.bank=p.money.bank-1;return p.money.bank end)
    tests[#tests+1]=B.measure('inventory_slot_direct',iterations,rounds,function(i)return p.inventory[(i%12)+1]end)
    tests[#tests+1]=B.measure('inventory_item_scan_12',iterations,rounds,function()for i=1,#p.inventory do if p.inventory[i].name=='repairkit'then return i end end;return 0 end)
    tests[#tests+1]=B.measure('dirty_mark_lookup',iterations,rounds,function(i)local k=(i%virtualPlayers)+1;d.dirty[k]=true;local v=d.dirty[k];if k%10~=0 then d.dirty[k]=nil end;return v end)
    tests[#tests+1]=B.measure('callback_registry_lookup',iterations,rounds,function(i)return d.callbacks['bench:cb:'..((i%64)+1)]end)
    tests[#tests+1]=B.measure('hook_dispatch_8',math.min(iterations,50000),rounds,function()local ctx={value=0};for i=1,#d.hooks do d.hooks[i](ctx)end;return ctx.value end)
    tests[#tests+1]=B.measure('json_encode_player',jsonIterations,rounds,function()return json.encode(p)end)
    tests[#tests+1]=B.measure('json_decode_player',jsonIterations,rounds,function()return json.decode(encoded)end)
    tests[#tests+1]=B.measure('dirty_batch_collect',batchIterations,rounds,function()local out={};for src in pairs(d.dirty)do out[#out+1]=d.bySource[src]end;return #out end,{note='collect 10% dirty virtual players'})
    tests[#tests+1]=B.measure('queue_sort_clone',queueIterations,rounds,function()local q={};for i=1,math.min(#d.queue,1000)do local e=d.queue[i];q[i]={priority=e.priority,joined=e.joined}end;table.sort(q,function(a,b)if a.priority==b.priority then return a.joined<b.joined end return a.priority>b.priority end);return q[1].priority end,{note='clone and sort up to 1000 queue entries'})
    return {virtualPlayers=virtualPlayers,setupMemoryKb=B.round(d.memoryKb,2),tests=tests}
end

function B.runArchitectureModels(virtualPlayers, iterations, rounds)
    return {virtualPlayers=virtualPlayers,models={},note='Brand architecture models removed. Compare LIVE results on identical FXServer, data, and workload. Synthetic cases measure algorithms only.'}
end
