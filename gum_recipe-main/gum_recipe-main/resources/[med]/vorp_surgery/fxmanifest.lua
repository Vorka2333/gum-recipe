fx_version 'cerulean'
game 'rdr3'

name 'vorp_surgery'
author 'gum-recipe'
description 'Advanced trauma/surgery system for strict RP (VORP)'
version '0.1.1'

ui_page 'html/index.html'

shared_scripts {
    '@oxmysql/lib/MySQL.lua',
    'config.lua',
    'shared/*.lua'
}

server_scripts {
    'server/inventory_bridge.lua',
    'server/db.lua',
    'server/logs.lua',
    'server/injuries.lua',
    'server/surgery.lua',
    'server/admin.lua',
    'server/server.lua'
}

client_scripts {
    'client/effects.lua',
    'client/interactions.lua',
    'client/nui_bridge.lua',
    'client/client.lua'
}

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/assets/*.svg'
}

lua54 'yes'
