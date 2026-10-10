-- Copyright (c) 2026 Sprite Viewer contributors.
-- SPDX-License-Identifier: MIT
-- Pure geometry calculations. No graphics, input, filesystem or SDL state.
-- A sprite dimension callback is used because original sheets are lazy-loaded.
local Layout = {}

-- Index row boundaries while doing the initial sheet layout.  Layout is
-- cached by table, zoom and viewport width; rows let redraws visit only the
-- visible portion, without a linear scan through every sprite each frame.
function Layout.sheet(count, size_of, text_size, width, zoom, header_height)
  local x, y, tallest, cells, rows = 0, header_height, 0, {}, {}
  local row_first = 1
  for id = 0, count - 1 do
    local w, h = size_of(id)
    local image_w, image_h = w * zoom, h * zoom
    local label_w, label_h = text_size('#' .. id .. ' ' .. w .. 'x' .. h)
    local cell_w = math.max(image_w, label_w + 18, 28) + 6
    local cell_h = image_h + label_h + 7
    if x > 0 and x + cell_w > width then
      rows[#rows + 1] = {first = row_first, last = #cells,
        y = y, bottom = y + tallest}
      x, y, tallest = 0, y + tallest, 0
      row_first = #cells + 1
    end
    cells[#cells + 1] = {id = id, x = x, y = y, w = cell_w,
      h = cell_h, img_w = image_w, label_h = label_h}
    tallest = math.max(tallest, cell_h)
    x = x + cell_w + 2
  end
  if #cells >= row_first then
    rows[#rows + 1] = {first = row_first, last = #cells,
      y = y, bottom = y + tallest}
  end
  return cells, y + tallest, rows
end

-- Return 1-based cell indices.  All sprites in the same row have the same y,
-- so binary searching row ends finds the first possibly visible row, then
-- only rows intersecting the viewport are visited. No per-frame allocations.
function Layout.visible_range(rows, scroll, header_height, screen_height)
  local viewport_top = header_height - scroll
  local viewport_bottom = screen_height - scroll
  local low, high = 1, #rows
  while low <= high do
    local mid = math.floor((low + high) / 2)
    if rows[mid].bottom <= viewport_top then
      low = mid + 1
    else
      high = mid - 1
    end
  end
  if low > #rows or rows[low].y >= viewport_bottom then
    return 1, 0
  end
  local last = low
  while last < #rows and rows[last + 1].y < viewport_bottom do
    last = last + 1
  end
  return rows[low].first, rows[last].last
end

function Layout.clamp_scroll(total, viewport_height, header_height, offset)
  local available = math.max(1, viewport_height - header_height)
  local content_height = total - header_height
  local max_up = math.max(0, content_height - available)
  return math.min(0, math.max(-max_up, offset))
end

function Layout.assembly_bounds(items, mode, size_of)
  local min_x, min_y, max_x, max_y = 0, 0, 0, 0
  for _, item in ipairs(items) do
    local w, h = size_of(item.id)
    if mode == 'strip' then
      max_x = max_x + w * item.repeat_count
      max_y = math.max(max_y, h)
    else
      min_x = math.min(min_x, item.dx)
      min_y = math.min(min_y, item.dy)
      max_x = math.max(max_x, item.dx + w)
      max_y = math.max(max_y, item.dy + h)
    end
  end
  return min_x, min_y, max_x, max_y
end

-- Normalise negative layer offsets, centre short composites in the available
-- workspace, and clamp horizontal strip panning. Rendering never edits the
-- source sprite sizes or the user's saved assembly offsets.
function Layout.assembly_placement(sw, sh, header_height, zoom,
                                   min_x, min_y, max_x, max_y, mode, pan_x)
  local width = math.max(1, max_x - min_x)
  local height = math.max(1, max_y - min_y)
  local max_h = math.max(1, sh - header_height - 100)
  local fit = math.max(1, math.min(zoom,
    math.floor(sw / width), math.floor(max_h / height)))
  local pan_min = mode == 'strip' and math.min(0, sw - width * fit) or 0
  local pan = mode == 'strip' and math.min(0, math.max(pan_min, pan_x)) or 0
  local x = math.max(0, math.floor((sw - width * fit) / 2)) + pan
  local y = header_height + math.max(10,
    math.floor((max_h - height * fit) / 2))
  return {width = width, height = height, scale = fit,
          pan_x = pan, pan_min = pan_min, x = x, y = y}
end

-- Keep an explicitly focused component visible while keyboard/click browsing.
-- The strip can be wider than the viewport; positioning its source artwork is
-- never changed, only the viewport pan.  On entering assembly the focused
-- component is revealed to avoid an invisible active selection.
function Layout.reveal_strip(items, size_of, focus_id, viewport_width, zoom, pan)
  local x, target_start, target_end = 0, nil, nil
  for _, item in ipairs(items) do
    local w = size_of(item.id)
    local span = w * item.repeat_count * zoom
    if item.id == focus_id then
      target_start, target_end = x, x + span
    end
    x = x + span
  end
  local min_pan = math.min(0, viewport_width - x)
  pan = math.max(min_pan, math.min(0, pan))
  if not target_start or min_pan == 0 then return pan end
  if target_end - target_start > viewport_width then
    -- A component larger than the viewport is aligned at its left edge.
    pan = -target_start
  elseif target_start + pan < 0 then
    pan = -target_start
  elseif target_end + pan > viewport_width then
    pan = viewport_width - target_end
  end
  return math.max(min_pan, math.min(0, pan))
end

return Layout
