rockspec_format = '3.0'
package = 'wowcig'
version = 'scm-0'
description = {
  summary = 'WoW client interface generator',
  license = 'MIT',
  homepage = 'https://github.com/ferronn-dev/wowcig',
  issues_url = 'https://github.com/ferronn-dev/wowcig/issues',
  maintainer = 'ferronn@ferronn.dev',
  labels = {'wow'},
}
source = {
  url = 'https://github.com/ferronn-dev/wowcig/archive/refs/tags/vscm.tar.gz',
  dir = 'wowcig-scm',
}
dependencies = {
  'lua = 5.1',
  'argparse',
  'lua-path',
  'luabitop',
  'luacasc',
  'luadbd = 0.3',
  'luaexpat',
  'luafilesystem',
  'luasocket',
  'lzlib',
  'md5',
}
build = {
  type = 'none',
  install = {
    bin = {
      wowcig = 'wowcig.lua',
    },
  },
}
