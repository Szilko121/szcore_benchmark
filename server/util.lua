SzCoreBench = SzCoreBench or {}
local B = SzCoreBench

local sink
B.sink = function(v) sink = v end
B.cpuMs = function() return (os.clock and os.clock() or 0) * 1000.0 end
B.wallMs = function() return GetGameTimer() end

function B.clampInt(value, min, max, fallback)
    local n = math.floor(tonumber(value) or fallback or min)
    if n < min then n = min end
    if n > max then n = max end
    return n
end

function B.round(n, digits)
    local p = 10 ^ (digits or 2)
    return math.floor((tonumber(n) or 0) * p + 0.5) / p
end

function B.count(tbl)
    local n = 0
    if type(tbl) == 'table' then for _ in pairs(tbl) do n = n + 1 end end
    return n
end

function B.safeCall(fn, ...)
    local args = table.pack(...)
    local out
    local ok, err = xpcall(function() out = table.pack(fn(table.unpack(args, 1, args.n))) end, debug.traceback)
    if not ok then return false, err end
    return true, out and table.unpack(out, 1, out.n)
end

local function percentile(sorted, p)
    if #sorted == 0 then return 0 end
    local idx = math.ceil(#sorted * p)
    if idx < 1 then idx = 1 end
    if idx > #sorted then idx = #sorted end
    return sorted[idx]
end

function B.measure(name, iterations, rounds, fn, opts)
    opts = opts or {}
    iterations = math.max(1, math.floor(iterations or 1))
    rounds = math.max(1, math.floor(rounds or 1))
    local warmup = math.min(opts.warmup or 250, iterations)
    local ok, err = B.safeCall(function()
        for i = 1, warmup do sink = fn(i) end
    end)
    if not ok then
        return { name = name, status = 'error', error = tostring(err), iterations = iterations, rounds = rounds }
    end

    local cpu, wall = {}, {}
    for r = 1, rounds do
        collectgarbage('step', 0)
        local w0, c0 = B.wallMs(), B.cpuMs()
        local pass, roundErr = B.safeCall(function()
            for i = 1, iterations do sink = fn(i) end
        end)
        local c1, w1 = B.cpuMs(), B.wallMs()
        if not pass then
            return { name = name, status = 'error', error = tostring(roundErr), iterations = iterations, rounds = rounds }
        end
        cpu[#cpu + 1] = math.max(0.0001, c1 - c0)
        wall[#wall + 1] = math.max(0, w1 - w0)
        if opts.yieldBetweenRounds ~= false then Wait(0) end
    end
    table.sort(cpu); table.sort(wall)
    local median = percentile(cpu, 0.50)
    local p95 = percentile(cpu, 0.95)
    return {
        name = name,
        status = 'ok',
        iterations = iterations,
        rounds = rounds,
        cpuMs = {
            min = B.round(cpu[1], 4),
            median = B.round(median, 4),
            p95 = B.round(p95, 4),
            max = B.round(cpu[#cpu], 4),
        },
        wallMs = {
            min = wall[1], median = percentile(wall, 0.50), p95 = percentile(wall, 0.95), max = wall[#wall]
        },
        opsPerSecond = math.floor(iterations / (median / 1000.0)),
        nsPerOp = B.round((median * 1000000.0) / iterations, 2),
        note = opts.note,
    }
end

function B.skipped(name, reason)
    return { name = name, status = 'skipped', reason = reason }
end

function B.resourceVersion(name)
    if GetResourceState(name) == 'missing' then return nil end
    return GetResourceMetadata(name, 'version', 0) or 'unknown'
end

function B.detectFramework()
    local detected = {}
    if GetResourceState('szcore') == 'started' then detected[#detected + 1] = 'szcore' end
    if GetResourceState('qbx_core') == 'started' then detected[#detected + 1] = 'qbox' end
    if GetResourceState('es_extended') == 'started' then detected[#detected + 1] = 'esx' end
    if #detected == 1 then return detected[1], detected end
    if #detected == 0 then return 'standalone', detected end
    return detected[1], detected
end

function B.isAllowed(source)
    if source == 0 then return true end
    if IsPlayerAceAllowed(source, SzCoreBenchConfig.AcePermission) then return true end
    if GetResourceState('szcore') == 'started' then
        local ok, allowed = pcall(function() return exports.szcore:IsAdmin(source) end)
        if ok and allowed then return true end
    end
    return false
end

function B.printResult(prefix, row)
    if row.status == 'ok' then
        print(('%s %-31s %10.3f ms median | %12d ops/s | %8.1f ns/op'):format(
            prefix, row.name, row.cpuMs.median, row.opsPerSecond, row.nsPerOp
        ))
    elseif row.status == 'skipped' then
        print(('%s %-31s SKIP: %s'):format(prefix, row.name, row.reason or 'n/a'))
    else
        print(('%s %-31s ERROR: %s'):format(prefix, row.name, row.error or 'unknown'))
    end
end
