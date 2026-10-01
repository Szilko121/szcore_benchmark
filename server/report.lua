local B=SzCoreBench
local RESOURCE=GetCurrentResourceName()

local function esc(s)
    s=tostring(s or '');return s:gsub('&','&amp;'):gsub('<','&lt;'):gsub('>','&gt;'):gsub('"','&quot;')
end
local function rows(tests)
    local out={}
    for _,r in ipairs(tests or {}) do
        if r.status=='ok' then
            out[#out+1]=('<tr><td>%s</td><td>OK</td><td>%.4f</td><td>%d</td><td>%.1f</td><td>%d × %d</td></tr>'):format(esc(r.name),r.cpuMs.median,r.opsPerSecond,r.nsPerOp,r.iterations,r.rounds)
        else out[#out+1]=('<tr><td>%s</td><td>%s</td><td colspan="4">%s</td></tr>'):format(esc(r.name),esc(r.status),esc(r.reason or r.error or '')) end
    end
    return table.concat(out,'\n')
end
local function section(title,tests)
    return ('<section><h2>%s</h2><table><thead><tr><th>Test</th><th>Status</th><th>Median CPU ms</th><th>ops/s</th><th>ns/op</th><th>Work</th></tr></thead><tbody>%s</tbody></table></section>'):format(esc(title),rows(tests))
end
function B.reportHtml(report)
    local parts={}
    parts[#parts+1]='<!doctype html><html lang="hu"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>SzCore Benchmark Report</title><style>body{font-family:Inter,system-ui,sans-serif;background:#0b0f14;color:#e8edf3;margin:0;padding:28px}main{max-width:1200px;margin:auto}.hero{background:#111923;border:1px solid #243142;border-radius:18px;padding:24px;margin-bottom:20px}h1{margin:0 0 8px}h2{margin-top:0}p,.muted{color:#9eacbc}section{background:#101720;border:1px solid #202c3a;border-radius:16px;padding:18px;margin:16px 0;overflow:auto}table{width:100%;border-collapse:collapse;min-width:760px}th,td{text-align:left;padding:10px 12px;border-bottom:1px solid #22303f}th{color:#9fc7ff}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:10px}.card{background:#0c1219;border:1px solid #22303f;border-radius:12px;padding:12px}.warn{border-left:4px solid #f5b642;padding:12px;background:#1b1710;border-radius:8px}</style></head><body><main>'
    parts[#parts+1]=('<div class="hero"><h1>SzCore Framework Benchmark Suite</h1><p>%s • %s %s • %s</p><div class="grid"><div class="card">Mode<br><b>%s</b></div><div class="card">Virtual players<br><b>%s</b></div><div class="card">Iterations<br><b>%s</b></div><div class="card">Real players<br><b>%s</b></div></div></div>'):format(esc(report.timestamp),esc(report.framework.label),esc(report.framework.version),esc(report.runId),esc(report.profile),esc(report.config.virtualPlayers),esc(report.config.iterations),esc(report.environment.playerCount))
    parts[#parts+1]='<div class="warn"><b>Fontos:</b> a szintetikus tesztek csak algoritmusokat mérnek. Márkák közötti összehasonlításhoz azonos környezetben futtatott LIVE API és valós klienses terhelési mérés szükséges.</div>'
    parts[#parts+1]=section('Common synthetic stress',report.synthetic and report.synthetic.tests)
    if report.models and report.models.models then
        for _,id in ipairs({'esx','qbox','szcore'}) do local m=report.models.models[id];if m then parts[#parts+1]=section(m.label,m.tests) end end
    end
    parts[#parts+1]=section('Live framework API',report.live and report.live.tests)
    local db=report.database or {};parts[#parts+1]=('<section><h2>Database</h2><pre>%s</pre></section>'):format(esc(json.encode(db)))
    parts[#parts+1]=('<section><h2>Environment</h2><pre>%s</pre></section>'):format(esc(json.encode(report.environment or {})))
    parts[#parts+1]='</main></body></html>'
    return table.concat(parts,'\n')
end

local function loadHistory()
    local raw=LoadResourceFile(RESOURCE,'benchmark-history.json');if not raw or raw=='' then return {} end
    local ok,data=pcall(json.decode,raw);return ok and type(data)=='table' and data or {}
end
function B.saveReport(report)
    local encoded=json.encode(report)
    SaveResourceFile(RESOURCE,'benchmark-latest.json',encoded,-1)
    SaveResourceFile(RESOURCE,'benchmark-latest.html',B.reportHtml(report),-1)
    SaveResourceFile(RESOURCE,('reports/%s.json'):format(report.runId),encoded,-1)
    SaveResourceFile(RESOURCE,('reports/%s.html'):format(report.runId),B.reportHtml(report),-1)
    local history=loadHistory();history[#history+1]={runId=report.runId,timestamp=report.timestamp,framework=report.framework,profile=report.profile,config=report.config,environment={playerCount=report.environment.playerCount}}
    while #history>SzCoreBenchConfig.HistoryLimit do table.remove(history,1) end
    SaveResourceFile(RESOURCE,'benchmark-history.json',json.encode(history),-1)
    return ('%s/benchmark-latest.json'):format(RESOURCE),('%s/benchmark-latest.html'):format(RESOURCE)
end
