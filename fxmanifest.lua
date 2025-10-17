fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'APCode'
description 'QB Inventory Rework by APCode'
version '2.4.4'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'locales/en.lua',
    'locales/*.lua',
    'config/config.lua',
    'config/vehicles.lua'
}

client_scripts {
    'client/main.lua',
    'client/drops.lua',
    'client/vehicles.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/functions.lua',
    'server/commands.lua',
    'server/compat.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/main.css',
    'html/app.js',
    'html/images/*.png',
}

exports {
    'HasItem'
}

dependency 'qb-weapons'
dependency 'qb-core'