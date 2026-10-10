-- Large-table geometry regression. Does not need the CorsixTH renderer.
local Layout = require('sprite_viewer_layout')
local calls = 0
local function size(id)
  calls = calls + 1
  if id % 137 == 0 then return 200, 55 end
  if id % 29 == 0 then return 0, 0 end
  return 12 + id % 19, 9 + id % 27
end
local function font(label)
  return #label * 6, 10
end
local count = 50000
for _, width in ipairs({320, 640}) do
  for _, zoom in ipairs({1, 2, 4}) do
    calls = 0
    local cells, total, rows = Layout.sheet(count, size, font, width, zoom, 56)
    assert(#cells == count and #rows > 0 and total > 56)
    assert(calls == count, 'dimensions should be queried exactly once per layout')
    assert(rows[1].first == 1 and rows[#rows].last == count)
    for i = 2, #rows do
      assert(rows[i].first == rows[i-1].last + 1,
        'rows must partition the complete sprite list')
      assert(rows[i].y == rows[i-1].bottom,
        'rows must not overlap or leave gaps')
    end
    for j = 0, 100 do
      local offset = -(total - 56) * j / 100
      local begin_i, end_i = Layout.visible_range(rows, offset, 56, 480)
      local top, bottom = 56 - offset, 480 - offset
      local first, last = nil, nil
      -- Deliberately slow, independent reference implementation.
      for _, row in ipairs(rows) do
        if row.y < bottom and row.bottom > top then
          first = first or row.first
          last = row.last
        end
      end
      assert(begin_i == (first or 1) and end_i == (last or 0),
        'visible row query differs from reference at scroll ' .. offset)
      assert(end_i - begin_i < 250,
        'scroll should never trigger a full-table redraw')
    end
    assert(calls == count, 'visible query must never request sprite dimensions')
    local c = cells[40000 + 1]
    assert(c.id == 40000 and c.y >= 56,
      'large indexed sprite jumps should be direct')
  end
end
local empty, height, rows = Layout.sheet(0, size, font, 320, 1, 56)
assert(#empty == 0 and height == 56 and #rows == 0)
local first, last = Layout.visible_range(rows, 0, 56, 200)
assert(first == 1 and last == 0)
print('PASS: 50,000-sprite contact sheet, six viewport/zoom layouts, binary row visibility, empty table')
