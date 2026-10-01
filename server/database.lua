local B=SzCoreBench

local function stats(samples)
    table.sort(samples)
    local sum=0;for i=1,#samples do sum=sum+samples[i] end
    local function pct(p) if #samples==0 then return 0 end local i=math.ceil(#samples*p);if i<1 then i=1 elseif i>#samples then i=#samples end;return samples[i] end
    return {samples=#samples,avgMs=B.round(#samples>0 and sum/#samples or 0,3),minMs=B.round(samples[1] or 0,3),medianMs=B.round(pct(.5),3),p95Ms=B.round(pct(.95),3),maxMs=B.round(samples[#samples] or 0,3)}
end

function B.runDatabase(samples)
    if GetResourceState('oxmysql')~='started' then return {status='skipped',reason='oxmysql not started'} end
    samples=B.clampInt(samples,1,250,25)
    local readTimes={};local readOk=0
    for i=1,samples do
        local s=B.cpuMs();local ok,res=pcall(MySQL.scalar.await,'SELECT 1');local e=B.cpuMs()
        if ok and tonumber(res)==1 then readOk=readOk+1 end;readTimes[#readTimes+1]=math.max(0,e-s);Wait(0)
    end
    local out={status='ok',read=stats(readTimes),readOk=readOk}
    if not SzCoreBenchConfig.DatabaseWriteTest then return out end
    local tableName=SzCoreBenchConfig.DatabaseScratchTable
    local valid=tableName:match('^[A-Za-z0-9_]+$')
    if not valid then out.write={status='skipped',reason='invalid scratch table name'};return out end
    local create=([[CREATE TABLE IF NOT EXISTS `%s` (id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,run_id VARCHAR(64) NOT NULL,payload LONGTEXT NOT NULL,created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,PRIMARY KEY(id),KEY ix_run(run_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]):format(tableName)
    local ok,err=pcall(MySQL.query.await,create)
    if not ok then out.write={status='error',error=tostring(err)};return out end
    local runId=('bench_%d_%d'):format(os.time(),math.random(100000,999999));local writeTimes={};local writeOk=0
    for i=1,samples do
        local payload=json.encode({i=i,ts=os.time(),data=('x'):rep(128)})
        local s=B.cpuMs();local pass,id=pcall(MySQL.insert.await,('INSERT INTO `%s` (run_id,payload) VALUES (?,?)'):format(tableName),{runId,payload});local e=B.cpuMs()
        if pass and id then writeOk=writeOk+1 end;writeTimes[#writeTimes+1]=math.max(0,e-s);Wait(0)
    end
    pcall(MySQL.query.await,('DELETE FROM `%s` WHERE run_id=?'):format(tableName),{runId})
    out.write=stats(writeTimes);out.write.ok=writeOk
    return out
end
