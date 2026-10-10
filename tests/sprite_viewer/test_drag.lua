-- v17 drag contracts: source-pixel calculations, native event signatures, and
-- exactly one undoable history edit per completed mouse drag.
local Drag = require('sprite_viewer_drag')
local item = {id=9, dx=-3, dy=6}
local d = Drag.begin(item, 2, 100, 100, 2)
assert(({Drag.position(d,102,102,false)})[1] == -3, 'small motion is a click')
local x,y = Drag.position(d,120,86,false)
assert(x == 7 and y == -1, 'zoom must convert screen to source pixels')
x,y = Drag.position(d,120,86,true)
assert(x==8 and y==0, 'Ctrl should snap to source-space 8px grid')
local dneg = Drag.begin({id=1,dx=0,dy=0},1,100,100,1)
x,y=Drag.position(dneg,87,95,false)
assert(x == -13 and y == -5)
x,y=Drag.position(dneg,87,95,true)
assert(x==-16 and y==-8, 'negative snapping must round symmetrically')
x,y=Drag.position(dneg,90000,-90000,false)
assert(x==4096 and y==-4096, 'drag must respect recipe coordinate limits')

Colours={Black=0,White=1,Magenta=2,Cyan=3,Yellow=4}
local mods={}
SDL={getTicks=function()return 0 end,getKeyModifiers=function()return mods end}
local text_lines={}
local font={}
function font:sizeOf(s)return #tostring(s)*6,10 end
function font:draw(_,s)text_lines[#text_lines+1]=tostring(s)end
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
local function render()text_lines={};h.frame(TheApp)end
local function says(s)
 for _,line in ipairs(text_lines)do if line:find(s,1,true)then return true end end
 return false
end
local function go(n)key('g');for d in tostring(n):gmatch('.')do key(d)end;key('Return')end
for i=1,3 do go(i);key('space')end
key('v');key('m');render()
assert(says('Focus #3') and says('history 0/0'))
-- Single click, no motion, no history.
assert(h.buttondown(nil,1,290,215));assert(h.buttonup(nil,1,290,215));render()
assert(says('history 0/0') and says('offset (0,0)'))
-- Thirty animation-like pointer events must commit exactly one undo snapshot.
assert(h.buttondown(nil,1,290,215))
for i=1,30 do assert(h.motion(nil,290+i,215+math.floor(i/3),1,1)) end
render();assert(says('DRAG') and says('offset (30,10)'))
assert(h.buttonup(nil,1,320,225));render()
assert(says('offset (30,10)') and says('history 1/0'))
key('z',{ctrl=true});render();assert(says('offset (0,0)') and says('history 0/1'))
key('y',{ctrl=true});render();assert(says('offset (30,10)') and says('history 1/0'))
-- Esc cancels a drag even after many motion events; it must not push history.
assert(h.buttondown(nil,1,330,225))
assert(h.motion(nil,345,240,15,15));render();assert(says('DRAG'))
key('escape');render();assert(says('offset (30,10)') and says('history 1/0'))
assert(not h.buttonup(nil,1,345,240),'cancelled drag must not commit on release')
-- Ctrl grid-snap keeps source-space positions multiples of 8.
assert(h.buttondown(nil,1,330,225))
mods.ctrl=true;h.motion(nil,347,233,17,8);assert(h.buttonup(nil,1,347,233));mods.ctrl=false
render();assert(says('offset (48,16)') and says('history 2/0'))
key('z',{ctrl=true});render();assert(says('offset (30,10)'))
-- No-op pointer movement must preserve redo even when mouseup arrives.
assert(h.buttondown(nil,1,330,225))
assert(h.motion(nil,331,226,1,1));assert(h.buttonup(nil,1,331,226));render()
assert(says('history 1/1'))
-- Mode change while button held cancels, not records a partial edit.
assert(h.buttondown(nil,1,330,225));h.motion(nil,335,229,5,4)
key('v');key('v');render()
assert(says('offset (30,10)') and says('history 1/1'))
-- Click outside artwork is not a drag.
assert(not h.buttondown(nil,1,10,216))
assert(not h.motion(nil,20,223,10,7))
-- Native SDL window resize cancels a pending drag.
assert(h.buttondown(nil,1,330,225));h.motion(nil,338,232,8,7)
h.window_resized();render()
assert(says('offset (30,10)') and says('history 1/1'))
h.keyup(nil,'q');assert(TheApp.eventHandlers==old)
print('PASS: drag threshold, zoom/grid snapping, live preview, single undo, cancellation, resize and redo integrity')
