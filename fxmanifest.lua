fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'pk_delivery'
author 'Poker Studio'
description 'City jobs: street sweeper, general store crate delivery, wagon supply run'
version '1.0.2'

dependencies {
    'pk_library',
    'oxmysql',
}

shared_scripts {
    'config.lua',
    'locales.lua',
    'shared/utils.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua', -- only used to read the faction in server/bridge.lua
    'server/bridge.lua',
    'server/ui.lua',
    'server/access.lua',
    'server/rewards.lua',
    'server/main.lua',
    'server/jobs/*.lua',
}

client_scripts {
    'client/bridge.lua',
    'client/ui.lua',
    'client/utils.lua',
    'client/main.lua',
    'client/jobs/*.lua',
}

escrow_ignore {
    'config.lua',
    'locales.lua',
}
