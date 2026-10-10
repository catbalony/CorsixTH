-- Copyright (c) 2026 Sprite Viewer contributors.
-- SPDX-License-Identifier: MIT
-- Pure source-pixel pointer delta calculations; no SDL state or game assets.
local Drag = {}

local LIMIT = 4096
local function round(n)
  if n >= 0 then return math.floor(n + 0.5) end
  return math.ceil(n - 0.5)
end

function Drag.begin(item, index, x, y, zoom)
  assert(zoom > 0 and zoom == math.floor(zoom), "invalid drag zoom")
  return {id = item.id, index = index, origin_x = item.dx,
    origin_y = item.dy, x = x, y = y, zoom = zoom}
end

-- Moves shorter than 3 display pixels do not count as a drag. This keeps
-- ordinary clicks, even with small hand tremor, outside undo history.
-- Ctrl snaps final coordinates to an 8-source-pixel grid; plain drag is
-- pixel-exact. Rounding is symmetric for negative pointer movement.
function Drag.position(start, x, y, snap)
  local dx, dy = x - start.x, y - start.y
  if math.max(math.abs(dx), math.abs(dy)) < 3 then
    return start.origin_x, start.origin_y
  end
  local nx = start.origin_x + round(dx / start.zoom)
  local ny = start.origin_y + round(dy / start.zoom)
  if snap then
    nx = round(nx / 8) * 8
    ny = round(ny / 8) * 8
  end
  return math.max(-LIMIT, math.min(LIMIT, nx)),
    math.max(-LIMIT, math.min(LIMIT, ny))
end

return Drag
