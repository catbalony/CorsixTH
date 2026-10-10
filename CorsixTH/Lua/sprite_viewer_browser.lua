-- Copyright (c) 2026 Sprite Viewer contributors.
-- SPDX-License-Identifier: MIT
-- Search and palette-selection logic independent of the SDL viewer.
local Browser = {}

-- Case-insensitive substring matches; retain the incoming deterministic order
-- and preserve each source index for selecting the real table/palette.
function Browser.filter(items, query, label)
  local out = {}
  local needle = (query or ''):lower()
  for i, item in ipairs(items) do
    local text = label and label(item) or item
    if text:lower():find(needle, 1, true) then
      out[#out + 1] = {index = i, text = text}
    end
  end
  return out
end

-- CorsixTH palettes frequently share a prefix with the DAT/TAB stem.
-- Require at least 3 shared characters, matching the original viewer.
function Browser.closest_palette(sprite_name, palettes)
  local best_score, best_index = 0, nil
  local lower_st = sprite_name:lower()
  for i, pal_name in ipairs(palettes) do
    local score = 0
    local lower_pal = pal_name:lower()
    for j = 3, math.min(#lower_pal, #lower_st) do
      if lower_pal:sub(1, j) == lower_st:sub(1, j) then
        score = j
      else
        break
      end
    end
    if score > best_score then best_score, best_index = score, i end
  end
  return best_index
end

return Browser
