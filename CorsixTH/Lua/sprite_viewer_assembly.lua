-- Copyright (c) 2026 Sprite Viewer contributors.
-- SPDX-License-Identifier: MIT
-- Small assembly edit model shared by keyboard and mouse controls.
-- Mutates one checked item or swaps the two ordered entries on success.
-- Offsets have a deliberate bound so a bad input cannot create huge bounds.
local Assembly = {}

local LIMIT = 4096

local function focused(items, id)
  for i, item in ipairs(items) do
    if item.id == id then return i, item end
  end
end

function Assembly.can(items, id, action)
  local index, item = focused(items, id)
  if not index then return false end
  if action == 'move-left' then return index > 1 end
  if action == 'move-right' then return index < #items end
  if action == 'copy-minus' then return item.repeat_count > 1 end
  if action == 'copy-plus' then return item.repeat_count < 99 end
  if action == 'dx-minus' then return item.dx > -LIMIT end
  if action == 'dx-plus' then return item.dx < LIMIT end
  if action == 'dy-minus' then return item.dy > -LIMIT end
  if action == 'dy-plus' then return item.dy < LIMIT end
  if action == 'reset' then
    return item.dx ~= 0 or item.dy ~= 0 or item.repeat_count ~= 1
  end
  return false
end

function Assembly.set_copies(items, id, count)
  local _, item = focused(items, id)
  if not item or type(count) ~= 'number' or count ~= count or
      count ~= math.floor(count) or count < 1 or count > 99 then
    return false
  end
  if item.repeat_count == count then return false end
  item.repeat_count = count
  return true
end

function Assembly.apply(items, id, action, step)
  local index, item = focused(items, id)
  if not index or not Assembly.can(items, id, action) then return false end
  if action == 'move-left' or action == 'move-right' then
    local target = index + (action == 'move-left' and -1 or 1)
    items[index], items[target] = items[target], items[index]
  elseif action == 'copy-minus' then
    item.repeat_count = item.repeat_count - 1
  elseif action == 'copy-plus' then
    item.repeat_count = item.repeat_count + 1
  elseif action == 'reset' then
    item.dx, item.dy, item.repeat_count = 0, 0, 1
  else
    local axis, direction = action:match('^(d[xy])%-(.+)$')
    local delta = (direction == 'plus') and 1 or -1
    -- Nudge supports one-pixel precision or Shift for an eight-pixel step.
    step = step == 8 and 8 or 1
    item[axis] = math.max(-LIMIT, math.min(LIMIT, item[axis] + delta * step))
  end
  return true
end

return Assembly
