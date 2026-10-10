-- Copyright (c) 2026 Sprite Viewer contributors.
-- SPDX-License-Identifier: MIT
-- Ordered selection operations, independent of CorsixTH and SDL.
-- The ordered item list is canonical; the lookup is rebuilt after mutations.
local Selection = {}

local function entry(id)
  return {id = id, dx = 0, dy = 0, repeat_count = 1}
end

local function indexed(items)
  local lookup = {}
  for _, item in ipairs(items) do lookup[item.id] = true end
  return lookup
end

function Selection.index(items, id)
  for i, item in ipairs(items) do
    if item.id == id then return i end
  end
  return nil
end

function Selection.toggle(items, _lookup, id)
  local result, found = {}, false
  for _, item in ipairs(items) do
    if item.id == id then found = true else result[#result + 1] = item end
  end
  if not found then result[#result + 1] = entry(id) end
  return result, indexed(result)
end

-- Add an inclusive numeric range to the end of the ordered selection. Existing
-- entries in the range retain offsets, repeat counts and their relative order
-- by sprite ID; unaffected entries retain their original order.
-- Cap BOTH range size and total output to prevent a stalled debug UI.
function Selection.range(items, _lookup, anchor, target, max_count)
  local first, last = math.min(anchor, target), math.max(anchor, target)
  local count = last - first + 1
  local outside, by_id = {}, {}
  for _, item in ipairs(items) do
    by_id[item.id] = item
    if item.id < first or item.id > last then
      outside[#outside + 1] = item
    end
  end
  if count > max_count or #outside + count > max_count then
    return nil, nil, ("Selection limit: %d sprites"):format(max_count)
  end
  local result = outside
  for id = first, last do
    result[#result + 1] = by_id[id] or entry(id)
  end
  return result, indexed(result)
end

function Selection.bulk(items, sprite_count, invert, max_count)
  if sprite_count > max_count then
    return nil, nil, ("%d sprites: bulk selection limited to %d"):format(
      sprite_count, max_count)
  end
  local by_id, result = {}, {}
  for _, item in ipairs(items) do by_id[item.id] = item end
  for id = 0, sprite_count - 1 do
    local existing = by_id[id]
    if (invert and not existing) or not invert then
      result[#result + 1] = existing or entry(id)
    end
  end
  return result, indexed(result)
end

function Selection.prune(items, sprite_count)
  local result = {}
  for _, item in ipairs(items) do
    if item.id >= 0 and item.id < sprite_count then
      result[#result + 1] = item
    end
  end
  return result, indexed(result)
end

return Selection
