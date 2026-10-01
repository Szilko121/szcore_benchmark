fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'SzCode / SzCore'
description 'Portable SzCore Framework Benchmark Suite for SzCore, Qbox and ESX'
version '1.4.0-rc1'

shared_script 'shared/config.lua'
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/util.lua',
    'server/adapters.lua',
    'server/synthetic.lua',
    'server/database.lua',
    'server/report.lua',
    'server/main.lua'
}

dependency 'oxmysql'
