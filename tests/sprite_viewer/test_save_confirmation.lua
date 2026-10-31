-- Run the real viewer event path with mocked SDL/game graphics. Each
-- Ctrl+S confirmation must identify the exact recipe path and contents.
local Recipe = require('sprite_viewer_recipe')
Colours = {Black=0, White=1, Magenta=2, Cyan=3, Yellow=4}
SDL = {getTicks=function() return 0 end, getKeyModifiers=function() return {} end}
local font = {}
function font:sizeOf(s) return #tostring(s)*6, 10 end
function font:draw() end
local canvas = {}
function canvas:getWidth() return 640 end
function canvas:getHeight() return 480 end
function canvas:startFrame() end
function canvas:endFrame() end
function canvas:fillColour() end
function canvas:drawRect(_,_,_,w,h) assert(w>0 and h>0) end
function canvas:mapRGB(r,g,b) return r*65536+g*256+b end
local sprite = {}
function sprite:size() return 48, 32 end
function sprite:draw() end
local gfx = {cache={tabled={}}}
function gfx:allPalettes() return {['MPalette.dat']=true} end
function gfx:getPalette(name) return name end
function gfx:loadSpriteTable()
  return setmetatable({}, {__index=sprite, __len=function() return 12 end})
end
function gfx:loadFontAndSpriteTable() return font end
local fs = {}
function fs:listFiles(dir)
  return dir == 'Data' and {
    ['PANEL02V.TAB']=true, ['PANEL04V.TAB']=true
  } or {}
end
function fs:fileExists() return true end
local root = 'tests/sprite_viewer'
local first = root .. '/SpriteViewer_Data_PANEL02V.svr'
local second = root .. '/SpriteViewer_Data_PANEL04V.svr'
for _, p in ipairs({first,second}) do
  os.remove(p); os.remove(p .. '.bak1'); os.remove(p .. '.tmp')
end
TheApp = {gfx=gfx, fs=fs, video=canvas, screenshot_dir=root,
          config={}, eventHandlers={}}
local original = TheApp.eventHandlers
assert(loadfile('CorsixTH/Lua/sprite_viewer.lua'))()()
local handlers = TheApp.eventHandlers
local function key(name, modifiers) handlers.keydown(nil, name, modifiers) end
local function save() key('s', {ctrl=true}) end
local function content_of(path)
  local file = assert(io.open(path, 'rb'))
  local result = assert(file:read('*a'))
  file:close()
  return result
end
-- PANEL02V is first in sorted resource order. Save one checked sprite.
key('space'); save()
local initial = content_of(first)
assert(initial:find('SVR1\tData\tPANEL02V\tcomplex\tstrip', 1, true))
-- First overwrite requires two consecutive saves without intervening edits.
key('k'); key('space'); save()
assert(content_of(first) == initial)
key('k'); key('space'); save()
assert(content_of(first) == initial,
  'changing checked sprites must invalidate an earlier overwrite confirmation')
save()
local updated = content_of(first)
assert(updated ~= initial)
assert(#assert(Recipe.parse(updated, 'Data', 'PANEL02V', true, 12)).items == 3)
assert(content_of(first .. '.bak1') == initial)
-- Arm another overwrite on the first table, then switch to another existing
-- file. A stale confirmation must NEVER overwrite that different table.
key('k'); key('space'); save()
assert(content_of(first) == updated)
local protected = Recipe.serialize('Data', 'PANEL04V', true, 'strip',
  {{id=7, dx=0, dy=0, repeat_count=1}})
assert(Recipe.save(second, protected, false))
key('d') -- changes to PANEL04V; resource switching resets checked sprites
key('space'); save()
assert(content_of(second) == protected,
  'a confirmation for PANEL02V must not silently replace PANEL04V')
save()
local replaced = content_of(second)
assert(replaced ~= protected and replaced:find('PANEL04V', 1, true))
assert(content_of(second .. '.bak1') == protected)
handlers.keyup(nil, 'q')
assert(TheApp.eventHandlers == original)
for _, p in ipairs({first,second}) do
  os.remove(p); os.remove(p .. '.bak1'); os.remove(p .. '.tmp')
end
print('PASS: per-path, per-content overwrite confirmation protects recipe files')
