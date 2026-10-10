-- Stable paging, boundaries and navigation through long checked lists.
local Layout = require('sprite_viewer_layout')
for _, capacity in ipairs({1, 5, 8, 12}) do
  for total = 1, 127 do
    for index = 1, total do
      local first, last, page, pages = Layout.assembly_page(index, total, capacity)
      assert(first <= index and index <= last)
      assert(last-first < capacity)
      assert(page == math.ceil(index / capacity))
      assert(pages == math.ceil(total / capacity))
      assert(first == (page-1)*capacity+1)
      local previous = Layout.assembly_page_target(index,total,capacity,-1)
      local next = Layout.assembly_page_target(index,total,capacity,1)
      assert(previous==math.max(1,first-capacity))
      assert(next==math.min(total,first+capacity))
    end
  end
end
local a,b,page,pages=Layout.assembly_page(1,0,5)
assert(a==1 and b==0 and page==0 and pages==0)
assert(Layout.assembly_page_target(1,0,5,-1)==nil)
assert(select(1,Layout.assembly_page(17,35,8))==17)
assert(select(1,Layout.assembly_page(18,35,8))==17,
  'focus within a page must not shift component strip')
-- Width-based overview and hit testing, including repeated pieces.
local pieces = {
  {id=1,repeat_count=1},
  {id=2,repeat_count=5},
  {id=3,repeat_count=1},
  {id=4,repeat_count=1},
}
local widths={[1]=80,[2]=100,[3]=0,[4]=200,[5]=41}
local function size(id) return widths[id],48 end
local overview=Layout.strip_overview(pieces,size,2,320,1,-250,8,304)
assert(overview and overview.view_x>8 and overview.view_width>0)
assert(overview.focus_x>=8 and overview.focus_x+overview.focus_width<=312)
assert(Layout.strip_pick(pieces,size,8,8,304)==1)
assert(Layout.strip_pick(pieces,size,100,8,304)==2)
assert(Layout.strip_pick(pieces,size,311,8,304)==4)
assert(Layout.strip_pick(pieces,size,312,8,304)==4)
assert(Layout.strip_pick(pieces,size,100,8,0)==nil)
assert(Layout.center_strip(pieces,size,1,320,1)==0)
assert(Layout.center_strip(pieces,size,4,320,1)==-460)
assert(Layout.strip_overview({pieces[1]},size,1,640,1,0,8,624)==nil)
assert(Layout.strip_pick({{id=3,repeat_count=3}},size,3,0,10)==nil)
-- Important Lua vararg edge case: size_of() returns (width, height).
-- A sprite narrower than its height must map by width, not max(width,height).
local tall_first = {{id=5, repeat_count=1}, {id=4, repeat_count=1}}
assert(Layout.strip_pick(tall_first, size, 40, 0, 241)==1)
assert(Layout.strip_pick(tall_first, size, 44, 0, 241)==2,
  'overview hit testing must use width only, not the sprite height')

print("PASS: stable pages, bounds, width-proportional overview, hit testing and centering")
