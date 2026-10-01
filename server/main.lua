local B=SzCoreBench
local running=false
math.randomseed(os.time()+GetGameTimer())

local function envInfo()
    local framework,all=B.detectFramework();local started=0
    for i=0,GetNumResources()-1 do local r=GetResourceByFindIndex(i);if r and GetResourceState(r)=='started' then started=started+1 end end
    return {
        frameworkDetected=framework,frameworksStarted=all,playerCount=#GetPlayers(),maxClients=GetConvarInt('sv_maxclients',48),
        onesync=GetConvar('onesync','unknown'),gameBuild=GetConvar('sv_enforceGameBuild','default'),
        oxmysqlVersion=B.resourceVersion('oxmysql'),startedResources=started,luaMemoryKb=B.round(collectgarbage('count'),2),
        serverVersion=GetConvar('version','unknown')
    }
end

local function resolveProfile(name,args)
    local base=SzCoreBenchConfig.Profiles[name]
    if base then return {virtualPlayers=base.virtualPlayers,iterations=base.iterations,rounds=base.rounds,dbSamples=base.dbSamples} end
    if name=='synthetic' or name=='custom' then
        return {virtualPlayers=B.clampInt(args[2],100,SzCoreBenchConfig.MaxVirtualPlayers,10000),iterations=B.clampInt(args[3],1000,SzCoreBenchConfig.MaxIterations,100000),rounds=B.clampInt(args[4],1,10,5),dbSamples=B.clampInt(args[5],1,250,25)}
    end
    return nil
end

local function run(source,profileName,args)
    if running then print('[FrameworkBench] Már fut egy benchmark.');return end
    local cfg=resolveProfile(profileName,args)
    if not cfg then print('[FrameworkBench] Ismeretlen profil. Használat: frameworkbench quick|full|extreme|synthetic [virtualPlayers] [iterations] [rounds] [dbSamples]|api|info');return end
    running=true
    local ok,err=xpcall(function()
        collectgarbage('collect')
        local env=envInfo();local fw=env.frameworkDetected;local adapter=B.getAdapter(fw)
        local runId=('%s_%s_%s'):format(os.date('!%Y%m%d_%H%M%S'),fw,math.random(1000,9999))
        print(('[FrameworkBench] START %s | framework=%s | virtual=%d | iterations=%d | rounds=%d'):format(profileName,fw,cfg.virtualPlayers,cfg.iterations,cfg.rounds))
        local report={schemaVersion=1,suiteVersion=SzCoreBenchConfig.Version,runId=runId,timestamp=os.date('!%Y-%m-%dT%H:%M:%SZ'),profile=profileName,config=cfg,environment=env}
        local c0=B.cpuMs();report.synthetic=B.runSynthetic(cfg.virtualPlayers,cfg.iterations,cfg.rounds);report.models=B.runArchitectureModels(cfg.virtualPlayers,cfg.iterations,cfg.rounds);report.syntheticTotalCpuMs=B.round(B.cpuMs()-c0,2)
        if adapter then
            local ctx=adapter.context();report.framework={id=adapter.id,label=adapter.label,version=adapter.version()};report.live={context=ctx,tests=adapter.tests(ctx,cfg.iterations,cfg.rounds)}
        else
            report.framework={id='standalone',label='Standalone / no supported framework detected',version='n/a'};report.live={tests={B.skipped('live_api','start szcore, qbx_core or es_extended')}}
        end
        report.database=B.runDatabase(cfg.dbSamples)
        collectgarbage('collect');report.environment.luaMemoryAfterKb=B.round(collectgarbage('count'),2)
        local jsonPath,htmlPath=B.saveReport(report)
        print(('[FrameworkBench] DONE %s %s | real players=%d'):format(report.framework.label,report.framework.version,env.playerCount))
        print(('[FrameworkBench] Synthetic dataset memory: %.2f KB'):format(report.synthetic.setupMemoryKb or 0))
        for _,r in ipairs(report.live.tests or {}) do B.printResult('[LIVE]',r) end
        print('[FrameworkBench] JSON: '..jsonPath);print('[FrameworkBench] HTML: '..htmlPath)
        print('[FrameworkBench] Más frameworkkel való korrekt összehasonlításhoz ugyanazt a profilt, gépet, artifactot és DB-t használd.')
    end,debug.traceback)
    running=false
    if not ok then print('[FrameworkBench] ERROR: '..tostring(err)) end
end

local function command(source,args)
    if not B.isAllowed(source) then if source>0 then TriggerClientEvent('chat:addMessage',source,{args={'Benchmark','Nincs jogosultságod.'}}) end;return end
    local action=(args[1] or 'full'):lower()
    if action=='info' then
        local fw,all=B.detectFramework();print(('[FrameworkBench] detected=%s, active=[%s], players=%d, suite=%s'):format(fw,table.concat(all,','),#GetPlayers(),SzCoreBenchConfig.Version));return
    end
    if action=='api' then
        if running then return end;running=true
        local ok,err=xpcall(function()
            local env=envInfo();local adapter=B.getAdapter(env.frameworkDetected);if not adapter then print('[FrameworkBench] Nincs támogatott framework.');return end
            local ctx=adapter.context();local iterations=B.clampInt(args[2],1000,SzCoreBenchConfig.MaxIterations,100000);local rounds=B.clampInt(args[3],1,10,5)
            print(('[FrameworkBench] LIVE API %s %s'):format(adapter.label,adapter.version()));local tests=adapter.tests(ctx,iterations,rounds);for _,r in ipairs(tests)do B.printResult('[LIVE]',r)end
        end,debug.traceback);running=false;if not ok then print('[FrameworkBench] ERROR: '..tostring(err))end;return
    end
    if action=='help' then
        print('frameworkbench quick|full|extreme|synthetic [virtualPlayers] [iterations] [rounds] [dbSamples]|api [iterations] [rounds]|info');return
    end
    run(source,action,args)
end
RegisterCommand('frameworkbench',command,false)
RegisterCommand('szcorebench',function(source,args)
    if #args>0 and tonumber(args[1]) then
        command(source,{'synthetic','10000',args[1],'5',args[2] or '25'})
    else command(source,args) end
end,false)
exports('DetectFramework',B.detectFramework)
exports('RunSynthetic',function(players,iterations,rounds)return B.runSynthetic(B.clampInt(players,100,SzCoreBenchConfig.MaxVirtualPlayers,10000),B.clampInt(iterations,1000,SzCoreBenchConfig.MaxIterations,100000),B.clampInt(rounds,1,10,5))end)
