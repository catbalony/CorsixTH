-- Bounded, independent history: snapshots must never alias edited data.
local H = require('sprite_viewer_history')
local A = require('sprite_viewer_assembly')
local items = {{id=1,dx=0,dy=0,repeat_count=1},{id=2,dx=2,dy=3,repeat_count=2}}
local h = H.new(3)
assert(not H.can_undo(h) and not H.can_redo(h))
assert(not H.perform(h,items,1,'move-left',function()return A.apply(items,1,'move-left')end))
assert(#h.past==0)
local function edit(id,action,step)
  return H.perform(h,items,id,action,function()return A.apply(items,id,action,step)end)
end
assert(edit(2,'move-left'))
assert(items[1].id==2 and #h.past==1)
assert(edit(2,'copy-plus') and items[1].repeat_count==3)
assert(edit(2,'dx-plus',8) and items[1].dx==10)
assert(edit(2,'dy-minus') and items[1].dy==2)
assert(#h.past==3, 'history is bounded at three states')
-- Undo retains copy values for other states, respects editing focus, and does
-- not alias the active state (editing it must not mutate history).
local focus,action
items,focus,action=H.undo(h,items,1)
assert(action=='dy-minus' and focus==2 and items[1].dy==3)
assert(items[1].dx==10)
items,focus,action=H.undo(h,items,1)
assert(action=='dx-plus' and focus==2 and items[1].dx==2)
assert(items[1].repeat_count==3)
items,focus,action=H.redo(h,items,1)
assert(action=='dx-plus' and focus==1 and items[1].dx==10)
assert(H.can_redo(h))
-- A denied edit does not clear the redo branch.
assert(not H.perform(h,items,1,'missing',function()return false end))
assert(H.can_redo(h))
-- Editing after undo invalidates redo and produces its own snapshot.
assert(edit(2,'copy-plus'))
assert(items[1].repeat_count==4 and not H.can_redo(h))
assert(H.redo(h,items,2)==nil)
items,focus,action=H.undo(h,items,2)
assert(action=='copy-plus' and items[1].repeat_count==3)
assert(H.lookup(items)[1] and H.lookup(items)[2])
-- Selection membership change must clear both stacks, so stale checked IDs
-- can never be brought back by Ctrl+Z.
H.clear(h)
assert(#h.past==0 and #h.future==0)
-- Snapshot count clamp never grows beyond specified limit.
local bounded=H.new(1)
for i=1,120 do
  assert(H.perform(bounded,items,2,'nudge',function()return A.apply(items,2,'dx-plus')end))
  assert(#bounded.past==1)
end
assert(H.new(200).limit==64 and H.new(0).limit==1)
print('PASS: bounded history, deep copy, reorder and offset undo/redo, redo invalidation and membership reset')
