-- Copyright (c) 2026 Sprite Viewer contributors.
-- SPDX-License-Identifier: MIT
-- Pure geometry calculations. No graphics, input, filesystem or SDL state.
-- A sprite dimension callback is used because original sheets are lazy-loaded.
local Layout = {}

function Layout.sheet(count, size_of, text_size, width, zoom, header_height)
  local x, y, tallest, cells = 0, header_height, 0, {}
  for id = 0, count - 1 do
    local w, h = size_of(id)
    local image_w, image_h = w * zoom, h * zoom
    local label_w, label_h = text_size('#' .. id .. ' ' .. w .. 'x' .. h)
    local cell_w = math.max(image_w, label_w + 18, 28) + 6
    local cell_h = image_h + label_h + 7
    if x > 0 and x + cell_w > width then
      x, y, tallest = 0, y + tallest, 0
    end
    cells[#cells + 1] = {id = id, x = x, y = y, w = cell_w,
      h = cell_h, img_w = image_w, label_h = label_h}
    tallest = math.max(tallest, cell_h)
    x = x + cell_w + 2
  end
  return cells, y + tallest
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

return Layout
