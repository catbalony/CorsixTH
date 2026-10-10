-- Integration regression: execute the real viewer Lua module with a 50k-sprite
-- graphics-table double. Unlike pure geometry tests this checks the caller's
-- frame loop, sprite hit targets, jumping, resizing, and retained cache.
Colours = {Black=0, White=1, Magenta=2, Cyan=3, Yellow=4}
SDL = {getTicks=function() return 0 end, getKeyModifiers=function() return {} end}
local sw, sh = 640, 480
local count, size_calls, frame_draws = 50000, 0, {}
local font = {}
function font:draw() end
function font:sizeOf(label) return #tostring(label) * 6, 10 end
local sprite = {}
function sprite:size(i)
  size_calls = size_calls + 1
  if i % 43 == 0 then return 80, 48 end
  return 12 + i % 17, 8 + i % 14
end
function sprite:draw(_, id)
  frame_draws[#frame_draws+1] = id
end
local canvas = {}
function canvas:startFrame() end
function canvas:endFrame() end
function canvas:fillColour() end
function canvas:getWidth() return sw end
function canvas:getHeight() return sh end
function canvas:mapRGB(r,g,b) return r*65536+g*256+b end
function canvas:drawRect(_, x, y, w, h)
  assert(w > 0 and h > 0, 'invalid rectangle')
end
local fs = {}
function fs:listFiles(dir)
  return dir=='Data' and {['PANEL04V.TAB']=true} or {}
end
function fs:fileExists() return true end
local gfx = {cache = {tabled = {}}}
function gfx:allPalettes() return {['MPalette.dat']=true} end
function gfx:getPalette(name) return name end
function gfx:loadSpriteTable()
  return setmetatable({}, {__index=sprite,__len=function()return count end})
end
function gfx:loadFontAndSpriteTable() return font end
TheApp={fs=fs,gfx=gfx,video=canvas,config={track_fps=true},eventHandlers={}}
local original=TheApp.eventHandlers
local open=assert(loadfile(arg[1] or 'CorsixTH/Lua/sprite_viewer.lua'))()
open()
local e=TheApp.eventHandlers
local function present()
  frame_draws={}
  e.frame(TheApp)
  assert(#frame_draws > 0 and #frame_draws < 200,
    'a redraw must touch only the visible sprite subset: ' .. #frame_draws)
end
local function goto_id(id)
  e.keydown(nil,'G')
  for d in tostring(id):gmatch('.') do e.keydown(nil,d) end
  e.keydown(nil,'Return')
end
present()
assert(size_calls >= count, 'first sheet layout must index all sprites')
local base=size_calls
for _=1,25 do present() end
assert(size_calls - base < 5000,
  'cached redraw unexpectedly performed O(N) size lookups')
local old_size_calls=size_calls
goto_id(49999)
present()
assert(frame_draws[#frame_draws] == 49999, 'jump must make last sprite visible')
assert(size_calls - old_size_calls < 200,
  'Go to sprite must use direct cell index, not a layout scan')
-- Scrolling is clamped correctly even with a very large sheet height.
e.mousewheel(nil, 0, -100000)
present()
assert(#frame_draws < 200)
-- Reflow after an actual SDL window-resize event.
sw,sh=320,200
assert(e.window_resized, "native SDL3 window_resized event must be registered")
e.window_resized(nil,sw,sh)
present()
assert(size_calls >= count*2, 'resizing did not rebuild the geometry cache')
goto_id(0)
present()
assert(frame_draws[1] == 0, 'small-window jump should show first sprite')
-- Switching palette invalidates source sprite table without losing the viewer.
e.keydown(nil,'P')
present()
assert(#frame_draws > 0)
e.keyup(nil,'Q')
assert(TheApp.eventHandlers == original)
print('PASS: 50,000-sprite actual viewer frame calls, O(visible) redraws, Go to #49999, resize, palette, exit')
