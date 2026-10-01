local B = SzCoreBench
B.adapters = {}

local function qboxAdapter()
    local adapter = { id = 'qbox', label = 'Qbox', resource = 'qbx_core' }
    function adapter.version() return B.resourceVersion('qbx_core') or 'unknown' end
    function adapter.context()
        local ctx = { job = SzCoreBenchConfig.DefaultJob, players = tonumber(GlobalState.PlayerCount) or #GetPlayers() }
        local ids = GetPlayers()
        local src = ids[1] and tonumber(ids[1]) or nil
        if src then
            local ok, player = pcall(function() return exports['qbx_core']:GetPlayer(src) end)
            if ok and player and player.PlayerData then
                ctx.source = src
                ctx.citizenid = player.PlayerData.citizenid
                ctx.job = player.PlayerData.job and player.PlayerData.job.name or ctx.job
            end
        end
        return ctx
    end
    function adapter.tests(ctx, iterations, rounds)
        local t = {}
        t[#t+1] = B.measure('api_get_jobs', iterations, rounds, function() return exports['qbx_core']:GetJobs() end)
        t[#t+1] = B.measure('api_get_job_definition', iterations, rounds, function() return exports['qbx_core']:GetJob(ctx.job) end)
        t[#t+1] = B.measure('api_duty_job_count', math.min(iterations, 100000), rounds, function()
            local count = exports['qbx_core']:GetDutyCountJob(ctx.job); return count
        end, { note = 'Qbox current GetDutyCountJob scans loaded players.' })
        t[#t+1] = B.measure('api_get_players_map', iterations, rounds, function() return exports['qbx_core']:GetQBPlayers() end)
        if ctx.source then
            t[#t+1] = B.measure('api_player_by_source', iterations, rounds, function() return exports['qbx_core']:GetPlayer(ctx.source) end)
            if ctx.citizenid then t[#t+1] = B.measure('api_player_by_citizenid', iterations, rounds, function() return exports['qbx_core']:GetPlayerByCitizenId(ctx.citizenid) end) end
            t[#t+1] = B.measure('api_metadata_read', iterations, rounds, function() return exports['qbx_core']:GetMetadata(ctx.source, 'hunger') end)
        else
            t[#t+1] = B.skipped('api_player_by_source', 'real player required')
            t[#t+1] = B.skipped('api_player_by_citizenid', 'real player required')
            t[#t+1] = B.skipped('api_metadata_read', 'real player required')
        end
        return t
    end
    return adapter
end

local function szcoreAdapter()
    local adapter = { id = 'szcore', label = 'SzCore', resource = 'szcore' }
    function adapter.version() return B.resourceVersion('szcore') or 'unknown' end
    function adapter.context()
        local ctx = { job = SzCoreBenchConfig.DefaultJob, players = exports.szcore:GetPlayerCount() }
        local ids = GetPlayers(); local src = ids[1] and tonumber(ids[1]) or nil
        if src then
            local ok, player = pcall(function() return exports.szcore:GetPlayer(src) end)
            if ok and player and player.PlayerData then
                ctx.source = src
                ctx.citizenid = player.PlayerData.citizenid
                ctx.job = player.PlayerData.job and player.PlayerData.job.name or ctx.job
            end
        end
        return ctx
    end
    function adapter.tests(ctx, iterations, rounds)
        local t = {}
        t[#t+1] = B.measure('api_player_count', iterations, rounds, function() return exports.szcore:GetPlayerCount() end)
        t[#t+1] = B.measure('api_get_jobs', iterations, rounds, function() return exports.szcore:GetJobs() end)
        t[#t+1] = B.measure('api_get_job_definition', iterations, rounds, function() return exports.szcore:GetJob(ctx.job) end)
        t[#t+1] = B.measure('api_duty_job_count', iterations, rounds, function() return exports.szcore:GetJobCount(ctx.job, true) end)
        t[#t+1] = B.measure('api_job_sources', math.min(iterations, 100000), rounds, function() return exports.szcore:GetPlayerSourcesByJob(ctx.job, true) end)
        if ctx.source then
            t[#t+1] = B.measure('api_player_by_source', iterations, rounds, function() return exports.szcore:GetPlayer(ctx.source) end)
            if ctx.citizenid then t[#t+1] = B.measure('api_player_by_citizenid', iterations, rounds, function() return exports.szcore:GetPlayerByCitizenId(ctx.citizenid) end) end
            t[#t+1] = B.measure('api_metadata_read', iterations, rounds, function() return exports.szcore:GetMetadata(ctx.source, 'hunger') end)
            if GetResourceState('szcore_inventory') == 'started' then
                t[#t+1] = B.measure('api_inventory_cached_read', math.min(iterations, 50000), rounds, function() return exports.szcore_inventory:GetPlayerInventory(ctx.source) end)
            end
        else
            t[#t+1] = B.skipped('api_player_by_source', 'real player required')
            t[#t+1] = B.skipped('api_player_by_citizenid', 'real player required')
            t[#t+1] = B.skipped('api_metadata_read', 'real player required')
            t[#t+1] = B.skipped('api_inventory_cached_read', 'real player required')
        end
        return t
    end
    return adapter
end

local function esxAdapter()
    local adapter = { id = 'esx', label = 'ESX Legacy', resource = 'es_extended' }
    local ESX
    local function shared() if not ESX then ESX = exports.es_extended:getSharedObject() end; return ESX end
    function adapter.version() return B.resourceVersion('es_extended') or 'unknown' end
    function adapter.context()
        local e = shared()
        local ctx = { job = SzCoreBenchConfig.DefaultJob, players = #GetPlayers() }
        local ids = GetPlayers(); local src = ids[1] and tonumber(ids[1]) or nil
        if src then
            local ok, xPlayer = pcall(function() return e.GetPlayerFromId(src) end)
            if ok and xPlayer then
                ctx.source = src
                ctx.identifier = xPlayer.identifier or (xPlayer.getIdentifier and xPlayer.getIdentifier())
                ctx.job = xPlayer.job and xPlayer.job.name or ctx.job
            end
        end
        return ctx
    end
    function adapter.tests(ctx, iterations, rounds)
        local e = shared(); local t = {}
        if e.GetNumPlayers then
            t[#t+1] = B.measure('api_player_count', iterations, rounds, function() return e.GetNumPlayers() end)
            t[#t+1] = B.measure('api_job_count', iterations, rounds, function() return e.GetNumPlayers('job', ctx.job) end)
        end
        if e.GetJobs then
            t[#t+1] = B.measure('api_get_jobs', iterations, rounds, function() return e.GetJobs() end)
            t[#t+1] = B.measure('api_get_job_definition', iterations, rounds, function() local jobs=e.GetJobs(); return jobs and jobs[ctx.job] end)
        elseif e.Jobs then
            t[#t+1] = B.measure('api_get_job_definition', iterations, rounds, function() return e.Jobs[ctx.job] end)
        end
        if e.GetExtendedPlayers then
            t[#t+1] = B.measure('api_job_player_list', math.min(iterations, 100000), rounds, function() return e.GetExtendedPlayers('job', ctx.job, true) end,
                { note = 'ESX current GetExtendedPlayers job filtering scans loaded players.' })
        end
        if ctx.source then
            t[#t+1] = B.measure('api_player_by_source', iterations, rounds, function() return e.GetPlayerFromId(ctx.source) end)
            if ctx.identifier and e.GetPlayerFromIdentifier then t[#t+1] = B.measure('api_player_by_identifier', iterations, rounds, function() return e.GetPlayerFromIdentifier(ctx.identifier) end) end
            local xPlayer = e.GetPlayerFromId(ctx.source)
            if xPlayer and xPlayer.getMeta then t[#t+1] = B.measure('api_metadata_read', iterations, rounds, function() return xPlayer.getMeta('hunger') end)
            else t[#t+1] = B.skipped('api_metadata_read', 'getMeta unavailable') end
        else
            t[#t+1] = B.skipped('api_player_by_source', 'real player required')
            t[#t+1] = B.skipped('api_player_by_identifier', 'real player required')
            t[#t+1] = B.skipped('api_metadata_read', 'real player required')
        end
        return t
    end
    return adapter
end

B.adapters.szcore = szcoreAdapter
B.adapters.qbox = qboxAdapter
B.adapters.esx = esxAdapter
function B.getAdapter(id) local factory = B.adapters[id]; if not factory then return nil end; return factory() end
