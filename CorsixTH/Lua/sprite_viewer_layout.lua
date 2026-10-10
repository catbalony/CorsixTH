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

-- These rectangles are shared by drawing and picking. A strip component owns
-- one rectangle covering all repeated copies, while layers have one rectangle
-- per source sprite (the last layer is rendered above earlier ones).
-- The rects are local preview coordinates, not persistent recipe offsets.
function Layout.assembly_rects(items, mode, size_of, placement, min_x, min_y)
  local result, cursor = {}, 0
  local zoom = placement.scale
  for i, item in ipairs(items) do
    local w, h = size_of(item.id)
    local x, y, rect_w
    if mode == 'strip' then
      x = placement.x + cursor * zoom
      y = placement.y + (placement.height - h) * zoom
      rect_w = w * item.repeat_count * zoom
      cursor = cursor + w * item.repeat_count
    else
      x = placement.x + (item.dx - min_x) * zoom
      y = placement.y + (item.dy - min_y) * zoom
      rect_w = w * zoom
    end
    result[i] = {index = i, id = item.id, x = x, y = y,
      w = rect_w, h = h * zoom}
  end
  return result
end

-- Bounding-box picking, not per-pixel alpha testing: sprite table draw() does
-- not expose a transparency mask. Ignore zero-sized sprites and any area
-- covered by the inspector header/footer. In layers, reverse draw order to
-- select the visual frontmost item; Shift-click cycles *under* the focus.
function Layout.assembly_pick(rects, x, y, focused_index, cycle,
                              preview_top, preview_bottom)
  if y < preview_top or y >= preview_bottom then return nil end
  local matches = {}
  for i = #rects, 1, -1 do
    local r = rects[i]
    if r.w > 0 and r.h > 0 and x >= r.x and x < r.x + r.w and
        y >= r.y and y < r.y + r.h then
      matches[#matches + 1] = r.index
    end
  end
  if #matches == 0 then return nil end
  if cycle and #matches > 1 then
    for i, index in ipairs(matches) do
      if index == focused_index then
        return matches[i % #matches + 1], #matches
      end
    end
  end
  return matches[1], #matches
end

-- Compact, predictable editing toolbar. The geometry is independent of
-- SDL, and the action names are implemented by sprite_viewer_assembly.lua.
-- It deliberately omits copy controls in layers mode: repeat_count affects
-- only strip assembly, so a layers-only copy button would be misleading.
function Layout.assembly_controls(screen_width, screen_height, mode)
  local entries = mode == "strip" and {
    {"move-left", "Order <"}, {"move-right", "Order >"},
    {"copy-minus", "Copies -"}, {"copy-plus", "Copies +"},
    {"reset", "Reset"}, {"undo", "Undo"}, {"redo", "Redo"},
  } or {
    {"move-left", "Order <"}, {"move-right", "Order >"},
    {"dx-minus", "X -"}, {"dx-plus", "X +"},
    {"dy-minus", "Y -"}, {"dy-plus", "Y +"},
    {"reset", "Reset"}, {"undo", "Undo"}, {"redo", "Redo"},
  }
  local gap = 5
  local available = math.max(1, screen_width - 16)
  local button_width = math.max(1,
    math.min(92, math.floor((available - gap * (#entries - 1)) / #entries)))
  local total_width = button_width * #entries + gap * (#entries - 1)
  local x = math.floor((screen_width - total_width) / 2)
  local result = {}
  for _, entry in ipairs(entries) do
    result[#result + 1] = {
      action = entry[1], label = entry[2],
      x = x, y = screen_height - 103, w = button_width, h = 20,
    }
    x = x + button_width + gap
  end
  return result
end

-- Pages remain stable as focus moves within a page; the component chips do
-- not jump around on every J/K keypress. Both click arrows and PageUp/Down
-- navigate to the first component of the adjacent page.
function Layout.assembly_page(index, count, capacity)
  if count <= 0 then return 1, 0, 0, 0 end
  capacity = math.max(1, math.floor(capacity))
  index = math.max(1, math.min(count, index))
  local page = math.floor((index - 1) / capacity) + 1
  local first = (page - 1) * capacity + 1
  return first, math.min(count, first + capacity - 1), page,
    math.ceil(count / capacity)
end

function Layout.assembly_page_target(index, count, capacity, direction)
  if count <= 0 then return nil end
  local first = Layout.assembly_page(index, count, capacity)
  return math.max(1, math.min(count, first + direction * math.max(1, math.floor(capacity))))
end

-- Shared source-space geometry for the narrow overview beneath a long
-- strip. Repeat counts contribute to width, while layer offsets do not.
local function StripExtent(items, size_of, active_index)
  local cursor, focus_start, focus_end = 0, 0, 0
  for index, item in ipairs(items) do
    local w = size_of(item.id)
    local span = math.max(0, w) * item.repeat_count
    if index == active_index then
      focus_start, focus_end = cursor, cursor + span
    end
    cursor = cursor + span
  end
  return cursor, focus_start, focus_end
end

-- Overview units are screen pixels. Return nil for a strip that already fits,
-- since a click target and a viewport marker would provide no navigation.
function Layout.strip_overview(items, size_of, active_index,
                               viewport_width, zoom, pan, bar_x, bar_width)
  if bar_width <= 0 or #items == 0 then return nil end
  local total, first, last = StripExtent(items, size_of, active_index)
  local screen_total = total * zoom
  if screen_total <= viewport_width or screen_total <= 0 then return nil end
  local function bar_position(px)
    local fraction = math.max(0, math.min(1, px / screen_total))
    return bar_x + math.floor(fraction * bar_width)
  end
  local vis_left = bar_position(-pan)
  local vis_right = bar_position(-pan + viewport_width)
  local focus_left = math.min(bar_x + bar_width - 1,
    bar_position(first * zoom))
  local focus_right = math.min(bar_x + bar_width,
    math.max(focus_left + 2, bar_position(last * zoom)))
  return {x = bar_x, width = bar_width,
    view_x = vis_left, view_width = math.max(1, vis_right - vis_left),
    focus_x = focus_left, focus_width = math.max(1, focus_right - focus_left)}
end

-- Click-to-locate uses source pixel width, NOT sprite count. This matches the
-- overview's proportional rendering even with long repeated segments.
function Layout.strip_pick(items, size_of, click_x, bar_x, bar_width)
  if bar_width <= 0 or #items == 0 then return nil end
  local total = StripExtent(items, size_of)
  if total <= 0 then return nil end
  local fraction = math.max(0, math.min(1,
    (click_x - bar_x + 0.5) / bar_width))
  local target, cursor = fraction * total, 0
  for index, item in ipairs(items) do
    -- size_of returns width AND height. Capture width before math.max: if the
    -- call is the final argument, Lua expands both results and taller sprites
    -- incorrectly occupy extra space in the overview hit map.
    local width = size_of(item.id)
    cursor = cursor + math.max(0, width) * item.repeat_count
    if target < cursor then return index end
  end
  return #items
end

-- Overview clicks deliberately centre the chosen component. Keyboard J/K
-- retains minimal-motion reveal, so ordinary stepping does not jump around.
function Layout.center_strip(items, size_of, active_index, viewport_width, zoom)
  local total, first, last = StripExtent(items, size_of, active_index)
  if total <= 0 then return 0 end
  local min_pan = math.min(0, viewport_width - total * zoom)
  local span = (last - first) * zoom
  local target = span > viewport_width and -first * zoom or
    math.floor(viewport_width / 2 - (first + last) * zoom / 2)
  return math.max(min_pan, math.min(0, target))
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
