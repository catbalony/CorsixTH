-- Pixel geometry without the CorsixTH renderer.
local Layout = require('sprite_viewer_layout')
local dims = {{25,3},{20,34},{11,8},{0,0}}
local function size(id)
  local d = dims[id + 1]
  return d[1], d[2]
end
local function label(s) return #s*6, 10 end
local cells, total = Layout.sheet(4, size, label, 150, 1, 56)
assert(#cells == 4 and cells[1].x == 0 and cells[1].y == 56)
assert(cells[2].y == 56 and cells[3].y > 56)
assert(cells[3].y == 107, 'row height must reset on wrap')
assert(total >= cells[#cells].y + cells[#cells].h)
local cells2, total2 = Layout.sheet(4, size, label, 320, 2, 56)
assert(cells2[2].y == 56 and total2 < 500)
assert(Layout.clamp_scroll(500, 200, 56, -9000) == -300)
assert(Layout.clamp_scroll(100, 480, 56, -100) == 0)
assert(Layout.clamp_scroll(500, 200, 56, 100) == 0)
local items = {
  {id=0,dx=-9,dy=-4,repeat_count=2},
  {id=1,dx=35,dy=10,repeat_count=1},
}
local x,y,xx,yy = Layout.assembly_bounds(items, 'strip', size)
assert(x == 0 and y == 0 and xx == 70 and yy == 34)
x,y,xx,yy = Layout.assembly_bounds(items, 'layers', size)
assert(x == -9 and y == -4 and xx == 55 and yy == 44)
local preview = Layout.assembly_placement(640,480,56,4,0,0,640,48,'strip',0)
assert(preview.width == 640 and preview.height == 48 and preview.scale == 1)
assert(preview.pan_min == 0 and preview.x == 0)
local wide = Layout.assembly_placement(640,480,56,4,0,0,792,48,'strip',-999)
assert(wide.pan_min == -152 and wide.pan_x == -152 and wide.x == -152)
local centre = Layout.assembly_placement(640,480,56,4,-10,-10,20,20,'layers',-500)
assert(centre.pan_x == 0 and centre.x == 260 and centre.y > 56)
local narrow = Layout.assembly_placement(320,200,56,2,0,0,640,48,'strip',-200)
assert(narrow.scale == 1 and narrow.pan_min == -320 and narrow.pan_x == -200)
print('PASS: contact-sheet wrap, scrolling bounds, negative layer offsets, pan & fit at 640/320')

-- Selecting a component from the assembly list should reveal its original
-- pixels without changing the saved offsets or the user's composition.
do
  local row = {}
  for id=1,9 do row[#row+1]={id=id,repeat_count=1,dx=0,dy=0} end
  local function width(_) return 88 end
  assert(Layout.reveal_strip(row,width,9,640,1,0)==-152,
    'last segment of 792px strip should be brought into view')
  assert(Layout.reveal_strip(row,width,1,640,1,-152)==0,
    'first segment should restore left side of strip')
  assert(Layout.reveal_strip(row,width,5,640,1,0)==0,
    'visible segment must not cause jumping')
  assert(Layout.reveal_strip(row,width,9,320,1,0)==-472,
    'narrow viewport must make last segment visible')
  assert(Layout.reveal_strip(row,width,7,320,1,-472)==-472,
    'already visible component must retain pan')
  assert(Layout.reveal_strip(row,width,100,320,1,-472)==-472,
    'unknown focus must not change the pan')
  local repeated={{id=2,repeat_count=9}}
  assert(Layout.reveal_strip(repeated,width,2,320,1,0)==0,
    'oversized single component should align its left edge')
  assert(row[9].dx==0 and row[9].dy==0 and row[9].repeat_count==1,
    'reveal operation must not edit model values')
end
