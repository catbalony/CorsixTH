-- Focus and selection are deliberately independent visual states.
-- Test render commands without guessing Theme Hospital palette or pixel data.
Colours = {Black=0, White=1, Magenta=2, Cyan=3, Yellow=4}
SDL = {getTicks=function() return 0 end, getKeyModifiers=function() return {} end}
local calls, w, h = {}, 640, 480
local font = {}
function font:sizeOf(text) return #tostring(text)*6, 10 end
function font:draw(_, text, x, y)
  calls[#calls+1] = {kind='text', value=tostring(text), x=x, y=y}
end
local canvas = {}
function canvas:startFrame() end
function canvas:endFrame() end
function canvas:fillColour() end
function canvas:getWidth() return w end
function canvas:getHeight() return h end
function canvas:mapRGB(r,g,b) return r*65536+g*256+b end
function canvas:drawRect(color,x,y,width,height)
  assert(width>0 and height>0)
  calls[#calls+1]={kind='rect',color=color,x=x,y=y,w=width,h=height}
end
local sprite = {}
function sprite:size(i) return i==0 and 40 or 25, 20 end
function sprite:draw(_,id,x,y) calls[#calls+1]={kind='sprite',id=id,x=x,y=y} end
local gfx={cache={tabled={}}}
function gfx:allPalettes() return {['MPalette.dat']=true} end
function gfx:getPalette(n) return n end
function gfx:loadSpriteTable() return setmetatable({}, {__len=function() return 6 end,__index=sprite}) end
function gfx:loadFontAndSpriteTable() return font end
local fs={}
function fs:listFiles(dir)
  return dir=='Data' and {['PANEL04V.TAB']=true} or {}
end
function fs:fileExists() return true end
TheApp={gfx=gfx,fs=fs,video=canvas,config={track_fps=true},eventHandlers={}}
local original=TheApp.eventHandlers
assert(loadfile(arg[1] or 'CorsixTH/Lua/sprite_viewer.lua'))()()
local e=TheApp.eventHandlers
local function render() calls={};e.frame(TheApp) end
local function find_rect(color,pred)
  for _,v in ipairs(calls) do
    if v.kind=='rect' and v.color==color and (not pred or pred(v)) then return v end
  end
end
local function text_match(s)
  for _,v in ipairs(calls) do
    if v.kind=='text' and v.value:find(s,1,true) then return true end
  end
end
local function key(k) e.keydown(nil,k) end
render()
-- Zero is focused without being checked. Its focus label is distinct from
-- the checked fill colour (which must not yet be present).
local focus_color=canvas:mapRGB(43,66,76)
local check_color=canvas:mapRGB(124,207,180)
assert(find_rect(focus_color),'focused label row has no focus background')
assert(not find_rect(check_color),'focus alone must not imply selection')
key('space'); render()
assert(find_rect(check_color),'checked sprite lacks its checkbox indicator')
key('k'); render()
assert(find_rect(check_color),'checked sprite state lost on focus change')
assert(text_match('>#1'),'moving focus must mark the newly focused sprite')
assert(text_match(' #0'),'previously checked sprite should not be focused')
key('space'); key('v'); render()
local edge=canvas:mapRGB(132,199,206)
assert(find_rect(edge,function(c) return c.h==1 and c.w>=25 end),
       'assembled component has no active preview outline')
assert(text_match('Focus #1'),'assembly inspector must identify edited component')
-- Wheel navigation must have the same focus/preview semantics as J/K, while
-- retaining independent checked selection state and assembly ordering.
assert(e.mousewheel(nil, 0, 1) == true)
render()
assert(text_match('Focus #0'),'wheel up should focus previous component')
assert(e.mousewheel(nil, 0, -1) == true)
render()
assert(text_match('Focus #1'),'wheel down should focus next component')
assert(find_rect(edge,function(c) return c.h==1 and c.w>=25 end),
       'wheel focus must update preview outline')
key('m');render()
assert(find_rect(edge,function(c) return c.h==1 and c.w>=25 end),
       'layered component has no active preview outline')
-- Invalid zero-sized sprites must not generate invalid graphics calls.
key('v'); key('q'); e.keyup(nil,'q')
assert(TheApp.eventHandlers==original)
print('PASS: distinct focused row and checked box, inspector outlines in strip/layers, restored event handlers')
