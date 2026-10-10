-- Assembly edits: pure model and the actual entrypoint's keyboard/mouse paths.
local Assembly = require('sprite_viewer_assembly')
local Layout = require('sprite_viewer_layout')
local items = {
  {id=1, dx=0, dy=0, repeat_count=1},
  {id=2, dx=-3, dy=4, repeat_count=2},
  {id=3, dx=0, dy=0, repeat_count=99},
}
assert(not Assembly.can(items,1,'move-left'))
assert(not Assembly.apply(items,1,'move-left'))
assert(Assembly.apply(items,2,'move-right'))
assert(items[3].id == 2 and items[2].id == 3, 'reorder must preserve item data')
assert(items[3].dx == -3 and items[3].repeat_count == 2)
assert(Assembly.apply(items,2,'copy-minus') and items[3].repeat_count == 1)
assert(not Assembly.apply(items,2,'copy-minus'))
assert(not Assembly.can(items,3,'copy-plus'))
assert(Assembly.apply(items,2,'copy-plus') and items[3].repeat_count == 2)
assert(Assembly.apply(items,2,'dx-plus',8) and items[3].dx == 5)
assert(Assembly.apply(items,2,'dy-minus') and items[3].dy == 3)
assert(Assembly.set_copies(items,2,17) and items[3].repeat_count == 17)
for _, n in ipairs({0,100,-5,5.5,0/0,math.huge}) do
  assert(not Assembly.set_copies(items,2,n),'invalid copies accepted: '..tostring(n))
end
items[3].dx,items[3].dy = 4095,-4095
assert(Assembly.apply(items,2,'dx-plus',8) and items[3].dx==4096)
assert(not Assembly.apply(items,2,'dx-plus'))
assert(Assembly.apply(items,2,'dy-minus',8) and items[3].dy==-4096)
assert(not Assembly.apply(items,2,'dy-minus'))
assert(Assembly.apply(items,2,'reset'))
assert(items[3].dx==0 and items[3].dy==0 and items[3].repeat_count==1)
assert(not Assembly.apply(items,2,'reset'))
assert(not Assembly.apply(items,404,'copy-plus'))
for _,mode in ipairs({'strip','layers'}) do
  for _,width in ipairs({320,640,800}) do
    local boxes=Layout.assembly_controls(width,480,mode)
    assert(#boxes==(mode=='strip' and 5 or 7))
    local last=-1
    for _,box in ipairs(boxes) do
      assert(box.x>=0 and box.x+box.w<=width)
      assert(box.x>last,'buttons overlap')
      assert(box.y==377 and box.h==20)
      last=box.x+box.w
    end
  end
end
-- The real Lua event dispatcher is driven here; the graphics and data tables
-- alone are test doubles. This catches differing keyboard/mouse edit code.
Colours={Black=0,White=1,Magenta=2,Cyan=3,Yellow=4}
local mods={}
SDL={getTicks=function()return 0 end, getKeyModifiers=function()return mods end}
local log={}
local font={}
function font:sizeOf(v)return #tostring(v)*6,10 end
function font:draw(_,text)log[#log+1]={kind='text',value=tostring(text)} end
local canvas={}
function canvas:getWidth()return 640 end
function canvas:getHeight()return 480 end
function canvas:startFrame()end
function canvas:endFrame()end
function canvas:fillColour()end
function canvas:drawRect(_,_,_,w,h)assert(w>0 and h>0)end
function canvas:mapRGB(r,g,b)return r*65536+g*256+b end
local sprite={}
function sprite:size(id)return id==0 and 25 or 88,48 end
function sprite:draw(_,id)log[#log+1]={kind='sprite',id=id} end
local gfx={cache={tabled={}}}
function gfx:allPalettes()return {['MPalette.dat']=true}end
function gfx:getPalette(v)return v end
function gfx:loadSpriteTable()return setmetatable({}, {__index=sprite,__len=function()return 12 end})end
function gfx:loadFontAndSpriteTable()return font end
local fs={}
function fs:listFiles(d)return d=='Data' and {['PANEL04V.TAB']=true} or {} end
function fs:fileExists()return true end
TheApp={gfx=gfx,fs=fs,video=canvas,config={},eventHandlers={}}
local original=TheApp.eventHandlers
assert(loadfile(arg[1] or 'CorsixTH/Lua/sprite_viewer.lua'))()()
local handlers=TheApp.eventHandlers
local function key(k,mod)handlers.keydown(nil,k,mod)end
local function render()log={};handlers.frame(TheApp)end
local function has(value)
  for _,x in ipairs(log)do if x.kind=='text' and x.value:find(value,1,true)then return true end end
end
local function draw_order()
  local ids={}
  for _,x in ipairs(log)do if x.kind=='sprite' then ids[#ids+1]=x.id end end
  return table.concat(ids,',')
end
local function go(id)
  key('g');for digit in tostring(id):gmatch('.') do key(digit)end;key('Return')
end
local function click_action(mode,action)
  local boxes=Layout.assembly_controls(640,480,mode)
  for _,box in ipairs(boxes)do
    if box.action==action then
      return handlers.buttondown(nil,1,box.x+math.floor(box.w/2),box.y+10)
    end
  end
  error('missing control: '..action)
end
render();go(1);key('space');key('k');key('space');key('k');key('space')
key('v');render()
assert(has('Focus #3') and draw_order()=='1,2,3')
assert(click_action('strip','move-left'));render()
assert(draw_order()=='1,3,2' and has('Focus #3'))
key(',');render();assert(draw_order()=='3,1,2','keyboard reorder differs from button')
key('.');render();assert(draw_order()=='1,3,2')
assert(click_action('strip','copy-plus'));render()
assert(has('copies 2') and draw_order()=='1,3,3,2')
key('n');key('4');key('Return');render()
assert(has('copies 4') and draw_order()=='1,3,3,3,3,2')
assert(click_action('strip','copy-minus'));render()
assert(has('copies 3') and draw_order()=='1,3,3,3,2')
key('m');render();assert(has('offset (0,0)'))
mods.shift=true;assert(click_action('layers','dx-plus'));mods.shift=false
render();assert(has('offset (8,0)'), 'Shift+mouse must nudge by 8')
key('up');render();assert(has('offset (8,-1)'), 'keyboard must use same nudge operation')
assert(click_action('layers','dy-plus'));render()
assert(has('offset (8,0)'))
assert(click_action('layers','reset'));render()
assert(has('offset (0,0)'))
key('m');render();assert(has('copies 1'),'reset must remove strip repetition')
assert(click_action('strip','move-right'));render()
assert(draw_order()=='1,2,3')
assert(not click_action('strip','move-right'), 'last component right button must be disabled')
-- Editing shortcuts must not mutate an assembly while back in gallery.
key('v');key(',');key('r');key('v');render()
assert(draw_order()=='1,2,3')
handlers.keyup(nil,'q');assert(TheApp.eventHandlers==original)
print('PASS: bounded assembly model and keyboard/mouse edit parity, button layout, Shift+nudge, disabled actions')
