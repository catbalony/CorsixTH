-- Exercises the real viewer module with failure-injecting resource loaders and
-- measured bitmap-font text at both native testing window sizes.
local source = arg[1] or 'CorsixTH/Lua/sprite_viewer.lua'
Colours = {Black=0, White=1, Magenta=2, Cyan=3, Yellow=4}
SDL = {getTicks=function() return 0 end, getKeyModifiers=function()return {} end}
local sw, sh = 320, 200
local calls = {}
local fail = {table=false, palette=false, decoder=false}
local font = {}
function font:sizeOf(t) return #tostring(t)*6, 10 end
function font:draw(_, t, x, y)
  calls[#calls+1]={text=tostring(t), x=x, y=y, w=#tostring(t)*6}
end
local canvas = {}
function canvas:getWidth() return sw end
function canvas:getHeight() return sh end
function canvas:startFrame() end
function canvas:endFrame() end
function canvas:fillColour() end
function canvas:drawRect(_, _, _, w, h) assert(w>0 and h>0) end
function canvas:mapRGB() return 0 end
local sprite = {}
function sprite:size(id) return id==0 and 20 or 24, 16 end
function sprite:draw() end
local fs = {}
function fs:listFiles(dir)
  return dir=='Data' and {['PANEL02V.TAB']=true,['PANEL04V.TAB']=true} or {}
end
function fs:fileExists() return true end
local gfx={cache={tabled={}}}
function gfx:allPalettes()return {['MPalette.dat']=true,['Pref01V.pal']=true} end
function gfx:getPalette(name)
  if fail.palette and name=='Pref01V.pal' then error('test corrupt palette') end
  return name
end
function gfx:loadSpriteTable(dir,name,complex,palette)
  if fail.table and name=='PANEL04V' then error('test corrupt DAT/TAB') end
  if fail.decoder and not complex then error('test invalid decode mode') end
  return setmetatable({}, {__index=sprite, __len=function()return 40 end})
end
function gfx:loadFontAndSpriteTable()return font end
TheApp={gfx=gfx,fs=fs,config={track_fps=true},video=canvas,eventHandlers={}}
local original=TheApp.eventHandlers
local open=assert(loadfile(source))()
open()
local e=TheApp.eventHandlers
local function frame()
  calls={}
  e.frame(TheApp)
end
local function find(s)
  for _, v in ipairs(calls) do if v.text:find(s,1,true) then return v end end
end
local function key(s,mods) e.keydown(nil,s,mods) end
local function assert_head_fits()
  for _,v in ipairs(calls) do
    if v.y >= 0 and v.y < 56 then
      assert(v.x>=0 and v.x+v.w<=sw+1,
        ('header text outside viewport (%dpx): %s at %d (%d)'):format(sw,v.text,v.x,v.w))
    end
  end
end
frame()
assert(find('Sprite viewer'))
assert(find('SHEET') and find('DETAIL') and find('BUILD') and find('FRAMES'))
assert_head_fits()
-- Click narrow-screen tab (its Y coordinate differs from full-screen mode).
assert(e.buttondown(nil,1,90,21))
frame(); assert(find('Sprite detail'))
assert_head_fits()
assert(e.buttondown(nil,1,18,21))
frame(); assert(find('Sprite viewer'))
-- Trigger a resource-switch failure; table path and selection must survive.
key('space'); frame(); assert(find('checked 1'))
fail.table=true
key('d');frame()
assert(find('PANEL02V') and find('Sprite load failed'))
assert(find('checked 1'))
assert_head_fits()
fail.table=false
key('d');frame()
assert(find('PANEL04V'))
-- Force palette failure; preserve source and selection after rollback.
key('space');frame();assert(find('checked 1'))
fail.palette=true
key('p');frame()
assert(find('Sprite load failed'))
assert(find('checked 1'))
fail.palette=false
key('p');frame()
assert(not find('Sprite load failed'))
-- Decode failure must restore the last known format without losing selection.
fail.decoder=true
key('c');frame()
assert(find('Sprite load failed') and find('checked 1'))
fail.decoder=false
key('c');frame()
assert(not find('Sprite load failed'))
-- Explicitly paginate F1 help; no hidden, unscrollable lower shortcuts.
key('f1');frame()
assert(find('1/'))
assert_head_fits()
key('down');frame()
assert(find('2/'))
key('escape');frame();assert(not find('Up/Down: page'))
-- Resize restores legacy tab positions and does not corrupt the loaded asset.
sw,sh=640,480
e.window_resized()
frame();assert(find('PANEL04V') and find('SHEET'))
assert_head_fits()
e.keyup(nil,'q')
assert(TheApp.eventHandlers==original)
print('PASS: compact tab hit targets, measured header clipping, help pagination, atomic resource/palette/decoder rollback and native resize event')
