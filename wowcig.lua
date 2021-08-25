local args = (function()
  local parser = require('argparse')()
  parser:option('-c --cache', 'cache directory', 'cache')
  parser:option('-e --extracts', 'extracts directory', 'extracts')
  parser:option('-p --product', 'WoW product'):choices({
    'wow',
    'wowt',
    'wow_classic',
    'wow_classic_era',
    'wow_classic_ptr',
  })
  return parser:parse()
end)()

local path = require('path')

local function normalizePath(p)
  -- path.normalize does not normalize x/../y to y.
  -- Unfortunately, we need exactly that behavior for Interface_Vanilla etc.
  -- links in per-product TOCs. We hack around it here by adding an extra dir.
  return path.normalize('a/' .. p):sub(3)
end

path.mkdir(args.cache)

local load, save, onexit = (function()
  local casc = require('casc')
  local url = 'http://us.patch.battle.net:1119/' .. args.product
  local bkey, cdn, ckey, version = casc.cdnbuild(url, 'us')
  assert(bkey)
  print('loading', version)
  local handle, err = casc.open({
    bkey = bkey,
    cdn = cdn,
    ckey = ckey,
    cache = args.cache,
    cacheFiles = true,
    locale = casc.locale.US,
    log = print,
  })
  if not handle then
    print('unable to open ' .. args.product .. ': ' .. err)
    os.exit()
  end
  local function load(f)
    return handle:readFile(f)
  end
  local function save(f, c)
    if not c then
      print('skipping', f)
    else
      print('writing ', f)
      local fn = path.join(args.extracts, version, f)
      path.mkdir(path.dirname(fn))
      local fd = assert(io.open(fn, 'w'))
      if type(c) == 'function' then
        c(function(s) fd:write(s) end)
      else
        fd:write(c)
      end
      fd:close()
    end
  end
  local function onexit()
    require('lfs').link(version, path.join(args.extracts, args.product), true)
  end
  return load, save, onexit
end)()

local function joinRelative(relativeTo, suffix)
  return normalizePath(path.join(path.dirname(relativeTo), suffix))
end

local processFile = (function()
  local lxp = require('lxp')
  local function doProcessFile(fn)
    local content = load(fn)
    save(fn, content)
    if (fn:sub(-4) == '.xml') then
      local parser = lxp.new({
        StartElement = function(_, name, attrs)
          local lname = string.lower(name)
          if (lname == 'include' or lname == 'script') and attrs.file then
            doProcessFile(joinRelative(fn, attrs.file))
          end
        end,
      })
      parser:parse(content)
      parser:close()
    end
  end
  return doProcessFile
end)()

local function processToc(tocName)
  local toc = load(tocName)
  save(tocName, toc)
  if toc then
    for line in toc:gmatch('[^\r\n]+') do
      if line:sub(1, 1) ~= '#' then
        processFile(joinRelative(tocName, line))
      end
    end
  end
end

local productSuffixes = {
  '',
  '_Vanilla',
  '_TBC',
  '_Mainline',
}

local function processAllProductFiles(addonDir)
  assert(addonDir:sub(1, 10) == 'Interface/', addonDir)
  local addonName = path.basename(addonDir)
  for _, suffix in ipairs(productSuffixes) do
    processToc(path.join(addonDir, addonName .. suffix .. '.toc'))
    processFile(path.join('Interface' .. suffix, addonDir:sub(11), 'Bindings.xml'))
  end
end

processAllProductFiles('Interface/FrameXML')

do
  local dbc = require('dbc')
  do
    local tocdb = assert(load(1267335))  -- DBFilesClient/ManifestInterfaceTOCData.db2
    for _, dir in dbc.rows(tocdb, 's') do
      processAllProductFiles(normalizePath(dir))
    end
  end
  do
    local function quote(s)
      return '[=[' .. s .. ']=]'
    end
    save('Interface/FrameXML/GlobalStrings.lua', function(write)
      write('-- generated by wowcig\n')
      local stringdb = assert(load(1394440))  -- DBFilesClient/GlobalStrings.db2
      for _, tag, text in dbc.rows(stringdb, 'ssu') do
        write(string.format('_G[(%s)] = %s\n', quote(tag), quote(text)))
      end
    end)
  end
end

onexit()
