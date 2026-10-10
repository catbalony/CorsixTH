-- Focused invariants for sprite-viewer selection.
local Selection = require('sprite_viewer_selection')
local function ids(items)
  local out = {}
  for _, item in ipairs(items) do out[#out+1] = item.id end
  return table.concat(out, ',')
end
local items, lookup = {}, {}
items, lookup = Selection.toggle(items, lookup, 6)
assert(ids(items) == '6' and lookup[6])
items[1].dx, items[1].repeat_count = -7, 25
items, lookup = Selection.range(items, lookup, 8, 5, 20)
assert(ids(items) == '5,6,7,8' and #items == 4)
assert(items[2].dx == -7 and items[2].repeat_count == 25)
items, lookup = Selection.range(items, lookup, 5, 8, 20)
assert(#items == 4 and ids(items) == '5,6,7,8', 'repeated range duplicated items')
items, lookup = Selection.toggle(items, lookup, 6)
assert(ids(items) == '5,7,8' and not lookup[6] and Selection.index(items, 6) == nil)
local before = ids(items)
local a,b,err = Selection.range(items, lookup, 1, 300000, 2048)
assert(a == nil and b == nil and err:find('limit') and ids(items) == before,
  'too-large selection must leave originals unchanged')
a,b,err = Selection.range(items, lookup, 8, 2054, 2048)
assert(a == nil and b == nil and ids(items) == before,
  'range plus outside items must obey the maximum')
local all, indices = Selection.bulk(items, 10, false, 2048)
assert(#all == 10 and all[5+1].id == 5 and all[5+1] == items[1])
local inv, inverted = Selection.bulk(items, 10, true, 2048)
assert(ids(inv) == '0,1,2,3,4,6,9' and inverted[6])
local too_many, _, reason = Selection.bulk(items, 100000, true, 2048)
assert(too_many == nil and reason:find('limited'))
local trimmed, result_lookup = Selection.prune({items[1], {id=77}, items[2]}, 7)
assert(ids(trimmed) == '5' and result_lookup[5] and not result_lookup[77])
print('PASS: independent ordered selection, range cap, offsets, bulk, prune and rejection without mutation')
