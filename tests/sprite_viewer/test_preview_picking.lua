-- Source-space geometry, overlap priority, bounds and real viewer dispatch.
local Layout = require('sprite_viewer_layout')
local dims = { [1]={20,10}, [2]={40,30}, [3]={10,50}, [4]={0,0}}
local function size(id) local d=dims[id]; return d[1],d[2] end
local items = {
  {id=1,dx=-5,dy=0,repeat_count=2},
  {id=2,dx=0,dy=-5,repeat_count=1},
  {id=3,dx=7,dy=0,repeat_count=1},
  {id=4,dx=1,dy=1,repeat_count=1},
}
local layer_minx, layer_miny, maxx, maxy = Layout.assembly_bounds(items,'layers',size)
local placement=Layout.assembly_placement(640,480,56,2,layer_minx,layer_miny,maxx,maxy,'layers',0)
local rects=Layout.assembly_rects(items,'layers',size,placement,layer_minx,layer_miny)
assert(rects[1].x == placement.x and rects[1].y == placement.y+5*placement.scale)
assert(rects[2].x == placement.x+5*placement.scale)
assert(rects[2].y == placement.y)
assert(rects[3].w==10*placement.scale and rects[3].h==50*placement.scale,
  'sprite height must not accidentally become hitbox width')
local x=rects[3].x+2*placement.scale
local y=rects[3].y+2*placement.scale
local hit, count=Layout.assembly_pick(rects,x,y,1,false,56,371)
assert(hit == 3 and count == 3, 'last-drawn layer must be picked first')
assert(Layout.assembly_pick(rects,x,y,3,true,56,371) == 2)
assert(Layout.assembly_pick(rects,x,y,2,true,56,371) == 1)
assert(Layout.assembly_pick(rects,x,y,1,true,56,371) == 3)
assert(Layout.assembly_pick(rects,x,y,4,true,56,371) == 3,
  'cycling from nonoverlapping focus must pick topmost')
assert(Layout.assembly_pick(rects,rects[3].x+rects[3].w, y, 1,false,56,371) == 2,
  'hitbox right edge must be exclusive')
assert(Layout.assembly_pick(rects,x,55,1,false,56,371) == nil)
assert(Layout.assembly_pick(rects,x,371,1,false,56,371) == nil)
assert(Layout.assembly_pick(rects,0,400,1,false,56,371) == nil,
  'footer clicks must not focus artwork')
local strip_bounds={Layout.assembly_bounds(items,'strip',size)}
local strip=Layout.assembly_placement(640,480,56,2,
  strip_bounds[1],strip_bounds[2],strip_bounds[3],strip_bounds[4],'strip',0)
local sr=Layout.assembly_rects(items,'strip',size,strip,0,0)
assert(sr[1].w==40*strip.scale and sr[2].x==sr[1].x+sr[1].w)
assert(Layout.assembly_pick(sr,sr[1].x+sr[1].w-1,sr[1].y+1,1,false,56,371)==1,
  'repeated strip copies belong to one component')
assert(Layout.assembly_pick(sr,sr[2].x+1,sr[2].y+1,1,false,56,371)==2)
assert(Layout.assembly_pick(sr,sr[4].x,sr[4].y,1,false,56,371)==nil,
  'zero-size sprites should be unpickable')

-- Dispatch real viewer mouse/key functions with a mock canvas; the geometry
-- is the same pure model used by the production renderer.
Colours={Black=0,White=1,Magenta=2,Cyan=3,Yellow=4}
local mods={}
SDL={getTicks=function()return 0 end,getKeyModifiers=function()return mods end}
local texts={}
local font={}
function font:sizeOf(s)return #tostring(s)*6,10 end
function font:draw(_,s)texts[#texts+1]=tostring(s)end
local canvas={}
function canvas:getWidth()return 640 end
function canvas:getHeight()return 480 end
function canvas:startFrame()end
function canvas:endFrame()end
function canvas:fillColour()end
function canvas:drawRect(_,_,_,w,h)assert(w>0 and h>0)end
function canvas:mapRGB(r,g,b)return r*65536+g*256+b end
local sprite={}
function sprite:size()return 88,48 end
function sprite:draw()end
local gfx={cache={tabled={}}}
function gfx:allPalettes()return {['MPalette.dat']=true}end
function gfx:getPalette(p)return p end
function gfx:loadSpriteTable()return setmetatable({},{__len=function()return 20 end,__index=sprite})end
function gfx:loadFontAndSpriteTable()return font end
local fs={}
function fs:listFiles(dir)return dir=='Data' and {['PANEL04V.TAB']=true} or {}end
function fs:fileExists()return true end
TheApp={gfx=gfx,fs=fs,video=canvas,config={},eventHandlers={}}
local old=TheApp.eventHandlers
assert(loadfile(arg[1] or 'CorsixTH/Lua/sprite_viewer.lua'))()()
local h=TheApp.eventHandlers
local function key(k,mod)h.keydown(nil,k,mod)end
local function render()
  local previous=texts
  texts={}
  h.frame(TheApp)
  if #texts==0 then texts=previous end
end
local function says(s)
  for _,line in ipairs(texts)do if line:find(s,1,true)then return true end end
  return false
end
local function go(n)key('g');for d in tostring(n):gmatch('.')do key(d)end;key('Return')end
for i=1,3 do go(i);key('space')end
key('v');key('m');render()
assert(says('Focus #3') and says('history 0/0'))
-- Layers: identical 88x48 rectangles centred at x276-364, y194-242.
assert(h.buttondown(nil,1,290,215));render();assert(says('Focus #3'))
mods.shift=true
assert(h.buttondown(nil,1,290,215));render();assert(says('Focus #2'))
assert(h.buttondown(nil,1,290,215));render();assert(says('Focus #1'))
assert(h.buttondown(nil,1,290,215));render();assert(says('Focus #3'))
mods.shift=false
assert(not h.buttondown(nil,1,10,215),'empty preview is not a component')
assert(not h.buttondown(nil,1,290,370),'footer region cannot select artwork')
assert(not h.buttondown(nil,1,290,55),'header region cannot select artwork')
render();assert(says('history 0/0'),'click focus must not add undo history')
-- Click #2 in overlap, edit it; clicking another layer does not clear history.
mods.shift=true;assert(h.buttondown(nil,1,290,215));mods.shift=false
key('right');render();assert(says('Focus #2') and says('history 1/0'))
assert(h.buttondown(nil,1,290,215));render()
assert(says('Focus #3') and says('history 1/0'))
key('z',{ctrl=true});render()
assert(says('Focus #2') and says('history 0/1'),
  'Undo should affect actual edit even after direct focus clicks')
-- Restore strip layout; click the repeated segment #1 to focus #1.
key('m');render()
-- Three 88px sprites, centred at x188..452 with bottom-aligned art y194.
assert(h.buttondown(nil,1,205,215));render();assert(says('Focus #1'))
assert(h.buttondown(nil,1,405,215));render();assert(says('Focus #3'))
h.keyup(nil,'q');assert(TheApp.eventHandlers==old)
print('PASS: direct sprite picking, repeated strips, topmost overlaps, Shift-cycle, bounds and history isolation')
