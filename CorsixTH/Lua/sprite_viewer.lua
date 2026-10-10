--[[ Copyright (c) 2009 Peter "Corsix" Cawley

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
--]]

-- This remains a debug sprite contact sheet, not a second editor or player.
-- Optional inspection modes compose a checked set of sprites or preview it as
-- frames. The contact sheet remains the default interface. Nothing is inferred
-- about animation sequences: the user chooses the frames and their order.
-- References: XCC Mixer SHP video viewer, OpenRA sequences, SLADE composite
-- patches, and Aseprite's optional timeline and frame-range playback.

local is_open = false
local gfx = TheApp.gfx
local SDL = rawget(_G, "SDL") or require("sdl")
local Recipe = require("sprite_viewer_recipe")
local Browser = require("sprite_viewer_browser")
local Selection = require("sprite_viewer_selection")
local Layout = require("sprite_viewer_layout")
local Assembly = require("sprite_viewer_assembly")
local History = require("sprite_viewer_history")
local Drag = require("sprite_viewer_drag")
local font -- Set on open
local need_draw = true
local sprite_table_paths = {}
local palettes = {}
local palette_index = 1
local palette_name
local sprite_table_index
local sprite_table
local is_complex = false
local wdown = false
local sdown = false
local scale = 1
local bg_colour_index = 1
local y_off = 0
local old_event_handlers
local old_gfx_cache = {}
local sprite_viewer_gfx_cache = {}
local mpalette_index

local background_colours = {
  Colours.Black,
  Colours.White,
  Colours.Magenta,
  Colours.Cyan,
  Colours.Yellow,
}

-- New state lives in this file; no changes to game resources or C++ required.
local view_mode = "sheet" -- sheet / assembly / animation
local assembly_mode = "strip" -- strip / layers
local assembly_pan_x = 0 -- viewport offset; source sprite offsets never change
local assembly_min_pan_x = 0
local focus_id = 0
local selected = {}  -- list of {id, dx, dy, repeat_count} in selection order
local selected_lookup = {} -- constant-time checkbox rendering, even for large tables
local assembly_history = History.new(32) -- bounded; no disk writes
local selection_anchor = nil -- first click/jump of a Shift-click range
local hit_boxes = {}
local assembly_hit_boxes = {}
local assembly_preview_rects = {}
local assembly_drag = nil -- pending layer drag; exactly one undo on mouse release
local sheet_layout_cache = nil
local header_height = 56
local entry_height = 0
local jump_mode = nil -- "sprite" or "copies"; nil when typing normally
local jump_text = ""
local notice = nil
local inspector_zoom = 4
local inspector_pan_x, inspector_pan_y = 0, 0
local inspector_checkerboard = true
local inspector_return_view = "sheet"
local header_hit_boxes = {}
local browser_kind = nil -- "table" or "palette"
local browser_query = ""
local browser_cursor = 1
local browser_results = {}
local browser_hit_boxes = {}
local recipe_overwrite_confirm = false
local screenshot_requested = false
local help_open = false
local help_page = 1

-- Animation is an INSPECTOR for the ordered checked set, not an editor.
-- A DAT/TAB table has no animation ranges or frame timing metadata, so FPS,
-- playback mode and sequence are explicitly user-controlled assumptions.
local animation_return_view = "sheet"
local animation_index = 1           -- 1-based index in selected[]
local animation_playing = false
local animation_fps = 8
local animation_zoom = 4  -- separate from gallery zoom
local animation_mode = "loop"       -- loop / once / pingpong
local animation_direction = 1
local animation_anchor = "bottom"   -- bottom / centre / top
local animation_last_tick = nil
local animation_hit_boxes = {}

local function MarkDirty()
  need_draw = true
end

-- Clip text by the bitmap font's *measured* pixel width, not by string length.
-- Resource paths and palette names are user data and need not fit in 320 px.
local function DrawFittedText(canvas, value, x, y, available)
  if available <= 0 then return end
  value = tostring(value)
  if font:sizeOf(value) <= available then
    font:draw(canvas, value, x, y)
    return
  end
  local suffix = ".."
  local suffix_width = font:sizeOf(suffix)
  if suffix_width > available then return end
  local left, right = 0, #value
  while left < right do
    local mid = math.floor((left + right + 1) / 2)
    if font:sizeOf(value:sub(1, mid)) + suffix_width <= available then
      left = mid
    else
      right = mid - 1
    end
  end
  font:draw(canvas, value:sub(1, left) .. suffix, x, y)
end

-- Prefer methods exposed by the real CorsixTH SDL surface (0.70.1).
-- Older test doubles and engines may provide getRenderSize instead.
local function GetViewerSize(canvas)
  if canvas.getWidth and canvas.getHeight then
    return canvas:getWidth(), canvas:getHeight()
  end
  return canvas:getRenderSize()
end

local function GetTimeMs()
  return SDL.getTicks()
end

local function ResetAnimation()
  animation_index = 1
  animation_playing = false
  animation_direction = 1
  animation_last_tick = nil
  animation_hit_boxes = {}
end

local function OpenAnimation()
  animation_return_view = view_mode
  view_mode = "animation"
  ResetAnimation()
  MarkDirty()
end

local function CloseAnimation()
  view_mode = animation_return_view
  ResetAnimation()
  MarkDirty()
end

local function SelectAnimationFrame(index)
  if #selected == 0 then
    animation_index = 1
  else
    animation_index = (index - 1) % #selected + 1
  end
  animation_direction = 1
  animation_last_tick = GetTimeMs()
  MarkDirty()
end

local function AdvanceAnimationFrame()
  local count = #selected
  if count < 2 then
    animation_playing = false
    return
  end
  if animation_mode == "loop" then
    animation_index = animation_index % count + 1
  elseif animation_mode == "once" then
    if animation_index >= count - 1 then
      animation_index = count
      animation_playing = false
    else
      animation_index = animation_index + 1
    end
  else -- pingpong: endpoints are not duplicated on direction reversal
    if animation_index == count then animation_direction = -1 end
    if animation_index == 1 then animation_direction = 1 end
    animation_index = animation_index + animation_direction
  end
end

local function ToggleAnimationPlayback()
  if #selected < 2 then
    animation_playing = false
    MarkDirty()
    return
  end
  if not animation_playing and animation_mode == "once" and
      animation_index == #selected then
    animation_index = 1
  end
  animation_playing = not animation_playing
  animation_last_tick = GetTimeMs()
  MarkDirty()
end


-- Selection model is independent of SDL rendering; the viewer owns focus,
-- notices and animation state, while the helper owns set/list invariants.
local MAX_BULK_SELECTION = 2048
local function IndexOf(id)
  return Selection.index(selected, id)
end

local function ToggleSelection(id)
  selected, selected_lookup = Selection.toggle(selected, selected_lookup, id)
  History.clear(assembly_history)
  focus_id, selection_anchor = id, id
  animation_index = math.min(animation_index, math.max(1, #selected))
  MarkDirty()
end

local function SelectRange(anchor, target)
  anchor = anchor or target
  local next_items, next_lookup, err = Selection.range(
    selected, selected_lookup, anchor, target, MAX_BULK_SELECTION)
  if not next_items then
    notice = err
    MarkDirty()
    return
  end
  selected, selected_lookup = next_items, next_lookup
  History.clear(assembly_history)
  focus_id, selection_anchor = target, anchor
  MarkDirty()
end

local function BulkSelect(invert)
  local next_items, next_lookup, err = Selection.bulk(
    selected, #sprite_table, invert, MAX_BULK_SELECTION)
  if not next_items then
    notice = err
  else
    selected, selected_lookup = next_items, next_lookup
    History.clear(assembly_history)
    animation_index = 1
    notice = string.format("%d sprites checked", #selected)
  end
  MarkDirty()
end

local function ClearSelection()
  History.clear(assembly_history)
  selected, selected_lookup = {}, {}
  selection_anchor = nil
  animation_index = 1
  notice = "Selection cleared"
  MarkDirty()
end

local function RevealFocusedStrip()
  if view_mode ~= "assembly" or assembly_mode ~= "strip" or #selected == 0 then return end
  local sw, sh = GetViewerSize(TheApp.video)
  local _, _, max_x, max_y = Layout.assembly_bounds(selected, "strip",
    function(id) return sprite_table:size(id) end)
  local placement = Layout.assembly_placement(sw, sh, header_height,
    scale, 0, 0, max_x, max_y, "strip", assembly_pan_x)
  assembly_pan_x = Layout.reveal_strip(selected,
    function(id) return sprite_table:size(id) end,
    focus_id, sw, placement.scale, assembly_pan_x)
end

local function FocusAssemblyIndex(index)
  local item = selected[index]
  if not item then return end
  focus_id = item.id
  RevealFocusedStrip()
  MarkDirty()
end

-- A drag previews source-pixel offsets in memory. Only the completed motion
-- is stored in history; Escape, reloading and view changes restore the start.
local function CancelAssemblyDrag()
  if not assembly_drag then return false end
  local d = assembly_drag
  assembly_drag = nil
  Assembly.set_offset(selected, d.id, d.origin_x, d.origin_y)
  MarkDirty()
  return true
end

local function CommitAssemblyDrag()
  if not assembly_drag then return false end
  local d = assembly_drag
  assembly_drag = nil
  local item = selected[d.index]
  if not item or item.id ~= d.id then return false end
  local final_x, final_y = item.dx, item.dy
  item.dx, item.dy = d.origin_x, d.origin_y
  if final_x == d.origin_x and final_y == d.origin_y then
    MarkDirty()
    return false
  end
  local changed = History.perform(assembly_history, selected, d.id, "drag layer",
    function() return Assembly.set_offset(selected, d.id, final_x, final_y) end)
  MarkDirty()
  return changed
end

local function FocusSelected(direction)
  if #selected == 0 then return end
  local index = IndexOf(focus_id) or 1
  index = (index - 1 + direction + #selected) % #selected + 1
  FocusAssemblyIndex(index)
end

-- A single edit path for all assembly controls; input handlers must not
-- independently mutate dx/dy, repeat counts or the checked-list order.
local function EditAssembly(action, step)
  if view_mode ~= "assembly" then return false end
  if not History.perform(assembly_history, selected, focus_id, action,
      function() return Assembly.apply(selected, focus_id, action, step) end) then
    return false
  end
  RevealFocusedStrip()
  MarkDirty()
  return true
end

local function UndoRedoAssembly(redo)
  if view_mode ~= "assembly" then return false end
  local items, focus, action
  if redo then
    items, focus, action = History.redo(assembly_history, selected, focus_id)
  else
    items, focus, action = History.undo(assembly_history, selected, focus_id)
  end
  if not items then return false end
  selected, selected_lookup = items, History.lookup(items)
  focus_id = focus
  notice = (redo and "Redid: " or "Undid: ") .. action
  RevealFocusedStrip()
  MarkDirty()
  return true
end

local function AssemblyPageCapacity()
  local width = GetViewerSize(TheApp.video)
  return math.max(1, math.floor((width - 40) / (width < 520 and 56 or 70)))
end

for _, dir in ipairs({"Data", "QData", "DataM", "QDataM"}) do
  for item in pairs(TheApp.fs:listFiles(dir) or {}) do
    if item:match("%.TAB$") then
      local basename = item:sub(1, -5)
      if TheApp.fs:fileExists(dir, basename .. ".DAT") then
        sprite_table_paths[#sprite_table_paths + 1] = {dir, basename}
      else
        print("Sprite table " .. dir .. "/" .. item .. " has no matching .DAT file. Skipping.")
      end
    end
  end
end
table.sort(sprite_table_paths, function(lhs, rhs)
  return lhs[1] < rhs[1] or (lhs[1] == rhs[1] and lhs[2] < rhs[2])
end)

for name in pairs(TheApp.gfx:allPalettes()) do
  palettes[#palettes + 1] = name
end
table.sort(palettes)

for i, name in ipairs(palettes) do
  if name == "MPalette.dat" then mpalette_index = i; break end
end

-- Palette detection is a pure helper in sprite_viewer_browser.lua.
-- Game-side callers load the HUD/PullDown/Watch tables in complex mode.
-- These are verified in CorsixTH's actual game Lua and PANEL04V live rendering.
-- Keep the manual C toggle for resources whose format is not known.
local complex_panel_tables = {
  PANEL02V = true, PANEL04V = true, PANEL02M = true,
  PULLDV = true, PULLDM = true,
  WATCH01V = true, WATCH01M = true,
}

local function DefaultComplex(path)
  return complex_panel_tables[path[2]:upper()] or false
end

-- Resource selection is a transaction: never discard the current sheet, its
-- checked sprites or scroll position until the replacement has loaded. A bad
-- DAT/TAB, decoder choice or palette must be visible as a notice, not a crash.
local last_loaded_complex, last_loaded_palette_index
local function TryLoadSheet(path, complex, palette_choice)
  local ok, result = pcall(function()
    local name = assert(palettes[palette_choice], "No palette available")
    local palette = gfx:getPalette(name)
    local sheet = gfx:loadSpriteTable(path[1], path[2], complex, palette)
    assert(sheet, "Sprite loader returned no table")
    local _ = #sheet -- Trigger malformed sprite-table metadata errors here.
    return sheet
  end)
  if not ok then return nil, tostring(result) end
  return result
end

local function ReportLoadFailure(err)
  local explanation = tostring(err):match("[^\r\n]+") or "Unknown loader error"
  notice = "Sprite load failed: " .. explanation
  MarkDirty()
  return false
end

local function LoadTable(n, complex, detect_palette)
  local path = sprite_table_paths[n]
  if not path then return false end
  if complex == nil then complex = DefaultComplex(path) end
  local choice = detect_palette and
    (Browser.closest_palette(path[2], palettes) or mpalette_index or 1) or palette_index
  local loaded, err = TryLoadSheet(path, complex, choice)
  if not loaded then return ReportLoadFailure(err) end
  sprite_table, sprite_table_index = loaded, n
  palette_index, palette_name = choice, palettes[choice]
  is_complex, last_loaded_complex = complex, complex
  last_loaded_palette_index = choice
  sheet_layout_cache = nil
  y_off = 0
  focus_id = 0
  selected = {}
  selected_lookup = {}
  History.clear(assembly_history)
  selection_anchor = nil
  assembly_pan_x = 0
  assembly_min_pan_x = 0
  jump_mode = nil
  notice = nil
  browser_kind = nil
  view_mode = "sheet"
  ResetAnimation()
  MarkDirty()
  return true
end

-- On unusual installations an isolated table can be damaged. Start with the
-- first readable one rather than leaving the debug viewer uninitialised.
if not LoadTable(1, nil, true) then
  for i = 2, #sprite_table_paths do
    if LoadTable(i, nil, true) then break end
  end
end
if not sprite_table then
  error("Sprite viewer: no readable DAT/TAB sprite table could be loaded")
end

local function ReLoadSameTable()
  -- Keep selections and scroll when simply changing the palette or decoding.
  local path = sprite_table_paths[sprite_table_index]
  local loaded, err = TryLoadSheet(path, is_complex, palette_index)
  if not loaded then
    -- Callers may already have changed the requested format or palette.
    is_complex = last_loaded_complex
    palette_index = last_loaded_palette_index
    return ReportLoadFailure(err)
  end
  sprite_table = loaded
  palette_name = palettes[palette_index]
  last_loaded_complex, last_loaded_palette_index = is_complex, palette_index
  sheet_layout_cache = nil
  -- A decoding-mode switch may change how many entries exist.
  local available = #sprite_table
  selected, selected_lookup = Selection.prune(selected, available)
  History.clear(assembly_history)
  focus_id = math.max(0, math.min(focus_id, available - 1))
  if selection_anchor and selection_anchor >= available then
    selection_anchor = nil
  end
  if animation_index > #selected then animation_index = math.max(1, #selected) end
  notice = nil
  MarkDirty()
  return true
end

local function LayoutSheet(screen_width)
  local cache = sheet_layout_cache
  if cache and cache.width == screen_width and cache.zoom == scale then
    return cache.cells, cache.total, cache.rows
  end
  local cells, total, rows = Layout.sheet(#sprite_table,
    function(i) return sprite_table:size(i) end,
    function(label) return font:sizeOf(label) end,
    screen_width, scale, header_height)
  sheet_layout_cache = {width = screen_width, zoom = scale,
                        cells = cells, total = total, rows = rows}
  return cells, total, rows
end

local function ClampScroll(screen_width, screen_height)
  local cells, total, rows = LayoutSheet(screen_width)
  y_off = Layout.clamp_scroll(total, screen_height, header_height, y_off)
  return cells, rows
end

local function ShowSprite(id)
  focus_id = math.max(0, math.min(#sprite_table - 1, id))
  selection_anchor = focus_id
  local sw, sh = GetViewerSize(TheApp.video)
  local cells = ClampScroll(sw, sh)
  local c = cells[focus_id + 1]
  if c then
    local top = c.y + y_off
    if top < header_height then y_off = header_height - c.y end
    if top + c.h > sh then y_off = sh - (c.y + c.h) end
    ClampScroll(sw, sh)
  end
  MarkDirty()
end

-- A single searchable picker handles resource names and palettes. This is a
-- navigation overlay, not a permanent sidebar; it preserves the contact sheet.
local function UpdateBrowserResults()
  local values = browser_kind == "table" and sprite_table_paths or palettes
  browser_results = Browser.filter(values, browser_query, browser_kind == "table" and
    function(item) return table.concat(item, "/") end or nil)
  browser_cursor = math.max(1, math.min(browser_cursor, #browser_results))
end

local function OpenBrowser(kind)
  browser_kind, browser_query, browser_cursor = kind, "", 1
  UpdateBrowserResults()
  MarkDirty()
end

local function ChooseBrowserItem()
  local hit = browser_results[browser_cursor]
  if not hit then return end
  local kind = browser_kind
  browser_kind = nil
  if kind == "table" then
    LoadTable(hit.index, nil, true)
  else
    palette_index = hit.index
    gfx.cache.tabled = {}
    ReLoadSameTable()
  end
  MarkDirty()
end

local function HandleBrowserKey(key)
  if key == "escape" then
    browser_kind = nil
  elseif key == "return" or key == "enter" then
    ChooseBrowserItem()
  elseif key == "up" or key == "down" then
    browser_cursor = math.max(1, math.min(#browser_results,
      browser_cursor + (key == "down" and 1 or -1)))
  elseif key == "pageup" or key == "pagedown" or key == "page up" or key == "page down" then
    browser_cursor = math.max(1, math.min(#browser_results,
      browser_cursor + ((key == "pageup" or key == "page up") and -6 or 6)))
  elseif key == "backspace" then
    browser_query = browser_query:sub(1, -2)
    browser_cursor = 1
    UpdateBrowserResults()
  elseif #key == 1 and key:match("[%w_%-%.]") and #browser_query < 32 then
    browser_query = browser_query .. key
    browser_cursor = 1
    UpdateBrowserResults()
  end
  MarkDirty()
  return true
end

-- Sidecar recipes are text, versioned, bounded and tied to one DAT/TAB table.
-- They NEVER write original TH resources.  The game's Screenshots directory
-- is the only output location; an unconfigured path fails visibly.
local function RecipePath()
  local path = sprite_table_paths[sprite_table_index]
  return Recipe.path(TheApp.screenshot_dir, path[1], path[2])
end

local function DisplayFilename(path)
  return path:match("([^/\\]+)$") or path
end

local function SaveRecipe()
  local path, err = RecipePath()
  if not path then notice = err; MarkDirty(); return end
  local source = sprite_table_paths[sprite_table_index]
  local blob = Recipe.serialize(source[1], source[2], is_complex, assembly_mode, selected)
  local ok, message, confirm = Recipe.save(path, blob, recipe_overwrite_confirm)
  recipe_overwrite_confirm = confirm
  notice = (ok and (message .. ": " .. DisplayFilename(path)) or message)
  MarkDirty()
end

local function LoadRecipe()
  local path, err = RecipePath()
  if not path then notice = err; MarkDirty(); return end
  local source = sprite_table_paths[sprite_table_index]
  local parsed, why = Recipe.load(path, source[1], source[2], is_complex, #sprite_table)
  if not parsed then notice = why; MarkDirty(); return end
  selected, selected_lookup = parsed.items, parsed.lookup
  History.clear(assembly_history)
  assembly_mode = parsed.mode
  animation_index = 1
  assembly_pan_x = 0
  if #selected > 0 then focus_id = selected[1].id end
  notice = string.format("Loaded %d components: %s", #selected, DisplayFilename(path))
  recipe_overwrite_confirm = false
  MarkDirty()
end

local function OpenView(mode)
  CancelAssemblyDrag()
  if mode == "animation" then
    if view_mode ~= "animation" then OpenAnimation() end
  elseif mode == "inspector" then
    if view_mode ~= "inspector" then inspector_return_view = view_mode end
    view_mode = "inspector"
  else
    if view_mode == "animation" then ResetAnimation() end
    view_mode = mode
    if mode == "assembly" and #selected > 0 and not IndexOf(focus_id) then
      focus_id = selected[1].id
    end
    if mode == "assembly" then RevealFocusedStrip() end
  end
  MarkDirty()
end

local function DoKey(_, rawchar, modifiers)
  local key = rawchar:lower()
  if assembly_drag then
    -- Modifier events may arrive during a drag as the user toggles snapping.
    if key == "left ctrl" or key == "right ctrl" or key == "left shift" or
        key == "right shift" or key == "lctrl" or key == "rctrl" then
      return false
    end
    CancelAssemblyDrag()
    if key == "escape" then return true end
  end
  modifiers = modifiers or {}
  if key == "f1" or key == "?" then
    help_open = not help_open
    help_page = 1
    MarkDirty()
    return true
  end
  if help_open then
    if key == "escape" then
      help_open = false
    elseif key == "down" or key == "pagedown" or key == "page down" then
      help_page = help_page + 1
    elseif key == "up" or key == "pageup" or key == "page up" then
      help_page = math.max(1, help_page - 1)
    end
    MarkDirty()
    return true
  end
  if browser_kind then return HandleBrowserKey(key) end
  if key == "x" then
    screenshot_requested = true
    notice = nil
    MarkDirty()
    return true
  end
  if modifiers.ctrl and (key == "z" or key == "y") then
    UndoRedoAssembly(key == "y" or modifiers.shift)
    return true
  end
  if modifiers.ctrl and key == "s" then
    SaveRecipe()
    return true
  end
  if modifiers.ctrl and key == "o" then
    LoadRecipe()
    return true
  end
  if modifiers.ctrl and key == "a" then
    BulkSelect(false)
    return true
  end
  if modifiers.ctrl and key == "i" then
    BulkSelect(true)
    return true
  end
  if jump_mode then
    if key == "return" or key == "enter" then
      local value = tonumber(jump_text)
      if value then
        if jump_mode == "sprite" then
          view_mode = "sheet"
          ShowSprite(math.floor(value))
        else
          if view_mode == "assembly" and History.perform(assembly_history,
              selected, focus_id, "set copies", function()
                return Assembly.set_copies(selected, focus_id,
                  math.max(1, math.min(99, math.floor(value))))
              end) then
            RevealFocusedStrip()
          end
        end
      end
      jump_mode, jump_text = nil, ""
    elseif key == "escape" then
      jump_mode, jump_text = nil, ""
    elseif key == "backspace" then
      jump_text = jump_text:sub(1, -2)
    elseif key:match("^%d$") and #jump_text < 5 then
      jump_text = jump_text .. key
    end
    MarkDirty()
    return true
  end

  if view_mode == "inspector" then
    if key == "i" or key == "escape" then
      OpenView(inspector_return_view)
      return true
    elseif modifiers.shift and
      (key == "left" or key == "right" or key == "up" or key == "down") then
      if key == "left" then inspector_pan_x = inspector_pan_x + 32 end
      if key == "right" then inspector_pan_x = inspector_pan_x - 32 end
      if key == "up" then inspector_pan_y = inspector_pan_y + 32 end
      if key == "down" then inspector_pan_y = inspector_pan_y - 32 end
      MarkDirty()
      return true
    elseif key == "left" or key == "right" then
      ShowSprite(focus_id + (key == "right" and 1 or -1))
      inspector_pan_x, inspector_pan_y = 0, 0
      return true
    elseif key == "0" then
      inspector_pan_x, inspector_pan_y = 0, 0
      MarkDirty()
      return true
    elseif key == "h" then
      inspector_checkerboard = not inspector_checkerboard
      MarkDirty()
      return true
    elseif key == "-" then
      inspector_zoom = math.max(1, inspector_zoom - 1)
      MarkDirty()
      return true
    elseif key == "=" or key == "+" then
      inspector_zoom = math.min(12, inspector_zoom + 1)
      MarkDirty()
      return true
    end
  end

  -- In preview mode, animation controls are specific and do not alter source.
  if view_mode == "animation" then
    if key == "t" or key == "escape" then
      CloseAnimation()
      return true
    elseif key == "space" then
      ToggleAnimationPlayback()
      return true
    elseif key == "left" or key == "right" then
      animation_playing = false
      SelectAnimationFrame(animation_index + (key == "right" and 1 or -1))
      return true
    elseif key == "j" or key == "k" then
      animation_playing = false
      SelectAnimationFrame(animation_index + (key == "k" and 1 or -1))
      return true
    elseif key == "[" or key == "left bracket" then
      animation_fps = math.max(1, animation_fps - 1)
      animation_last_tick = GetTimeMs()
      MarkDirty()
      return true
    elseif key == "]" or key == "right bracket" then
      animation_fps = math.min(30, animation_fps + 1)
      animation_last_tick = GetTimeMs()
      MarkDirty()
      return true
    elseif key == "l" then
      animation_mode = ({loop = "once", once = "pingpong", pingpong = "loop"})[animation_mode]
      animation_direction = 1
      animation_last_tick = GetTimeMs()
      MarkDirty()
      return true
    elseif key == "h" then
      animation_anchor = ({bottom = "centre", centre = "top", top = "bottom"})[animation_anchor]
      MarkDirty()
      return true
    end
  end

  -- Preserve the original controls. 'Q' is still handled by DoKeyUp.
  if key == "c" then
    is_complex = not is_complex
    gfx.cache.tabled = {}
    ReLoadSameTable()
  elseif key == "a" then
    if sprite_table_index > 1 then LoadTable(sprite_table_index - 1, nil, true) end
  elseif key == "d" then
    if sprite_table_index < #sprite_table_paths then LoadTable(sprite_table_index + 1, nil, true) end
  elseif key == "p" then
    if modifiers.shift then
      OpenBrowser("palette")
    else
      palette_index = palette_index % #palettes + 1
      gfx.cache.tabled = {}
      ReLoadSameTable()
    end
  elseif key == "f" then
    palette_index = Browser.closest_palette(sprite_table_paths[sprite_table_index][2], palettes) or mpalette_index or 1
    gfx.cache.tabled = {}
    ReLoadSameTable()
  elseif key == "w" then
    wdown = true
  elseif key == "s" then
    sdown = true
  elseif key == "-" then
    if view_mode == "animation" then
      animation_zoom = math.max(1, animation_zoom - 1)
    else
      scale = math.max(1, scale - 1)
    end
    MarkDirty()
  elseif key == "=" or key == "+" then
    if view_mode == "animation" then
      animation_zoom = math.min(8, animation_zoom + 1)
    else
      scale = math.min(8, scale + 1)
    end
    MarkDirty()
  elseif key == "b" then
    bg_colour_index = bg_colour_index % #background_colours + 1
    MarkDirty()
  elseif key == "v" then
    if view_mode == "animation" then
      CloseAnimation()
    else
      view_mode = view_mode == "sheet" and "assembly" or "sheet"
      if view_mode == "assembly" and #selected > 0 and
          not IndexOf(focus_id) then
        focus_id = selected[1].id
      end
      if view_mode == "assembly" then RevealFocusedStrip() end
    end
    MarkDirty()
  elseif key == "t" then
    OpenAnimation()
  elseif key == "i" then
    OpenView("inspector")
  elseif key == "u" then
    ClearSelection()
  elseif key == "m" then
    assembly_mode = assembly_mode == "strip" and "layers" or "strip"
    assembly_pan_x = 0
    MarkDirty()
  elseif key == "space" then
    if view_mode == "sheet" and modifiers.shift then
      SelectRange(selection_anchor, focus_id)
    else
      ToggleSelection(focus_id)
    end
  elseif view_mode == "assembly" and #selected > 0 and
      (key == "home" or key == "end" or key == "pageup" or
       key == "page up" or key == "pagedown" or key == "page down") then
    local index
    if key == "home" then
      index = 1
    elseif key == "end" then
      index = #selected
    else
      local direction = (key == "pageup" or key == "page up") and -1 or 1
      index = Layout.assembly_page_target(IndexOf(focus_id) or 1,
        #selected, AssemblyPageCapacity(), direction)
    end
    FocusAssemblyIndex(index)
  elseif key == "home" and view_mode == "sheet" then
    y_off = 0
    MarkDirty()
  elseif key == "end" and view_mode == "sheet" then
    y_off = -100000000 -- clamped by ClampScroll on render
    MarkDirty()
  elseif (key == "pageup" or key == "page up" or
          key == "pagedown" or key == "page down") and view_mode == "sheet" then
    local _, sh = GetViewerSize(TheApp.video)
    local direction = (key == "pageup" or key == "page up") and 1 or -1
    y_off = y_off + direction * math.max(32, sh - header_height - 24)
    MarkDirty()
  elseif key == "j" or key == "k" then
    local direction = key == "j" and -1 or 1
    if view_mode == "assembly" then
      FocusSelected(direction)
    else
      local anchor = selection_anchor or focus_id
      ShowSprite(focus_id + direction)
      if modifiers.shift then SelectRange(anchor, focus_id) end
    end
  elseif key == "/" or key == "slash" then
    OpenBrowser("table")
  elseif key == "g" then
    jump_mode, jump_text = "sprite", ""
    MarkDirty()
  elseif key == "n" then
    if view_mode == "assembly" and #selected > 0 then
      jump_mode, jump_text = "copies", ""; MarkDirty()
    end
  elseif key == "comma" or key == "," then
    EditAssembly("move-left")
  elseif key == "period" or key == "." then
    EditAssembly("move-right")
  elseif key == "left" or key == "right" or key == "up" or key == "down" then
    if view_mode == "assembly" and assembly_mode == "strip" then
      -- Pan the viewport only, leaving actual sprite positions unchanged.
      if key == "left" then
        assembly_pan_x = math.min(0, assembly_pan_x + 32)
      elseif key == "right" then
        assembly_pan_x = math.max(assembly_min_pan_x, assembly_pan_x - 32)
      end
      MarkDirty()
    elseif view_mode == "assembly" and assembly_mode == "layers" then
      local action = ({left = "dx-minus", right = "dx-plus",
        up = "dy-minus", down = "dy-plus"})[key]
      EditAssembly(action, modifiers.shift and 8 or 1)
    end
  elseif key == "r" then
    EditAssembly("reset")
  end
  return need_draw
end

local function DoKeyUp(_, rawchar)
  local key = rawchar:lower()
  -- Q is an exit shortcut only outside text-entry and help overlays.
  -- Otherwise typing 'q' into table/palette search closes the whole viewer
  -- on key release, even though keydown correctly edits the search query.
  if key == "q" and not (browser_kind or help_open or jump_mode) then
    CancelAssemblyDrag()
    TheApp.eventHandlers = old_event_handlers
    sprite_viewer_gfx_cache = gfx.cache.tabled
    gfx.cache.tabled = old_gfx_cache
    is_open = false
    return
  elseif key == "w" then wdown = false
  elseif key == "s" then sdown = false end
end

local function DoTextInput() return false end

local function DoMouseDown(_, button, x, y)
  CancelAssemblyDrag()
  if help_open then
    if button == 1 then help_open = false; MarkDirty() end
    return true
  end
  if browser_kind then
    if button == 1 then
      for _, hit in ipairs(browser_hit_boxes) do
        if x >= hit.x and x < hit.x + hit.w and
            y >= hit.y and y < hit.y + hit.h then
          browser_cursor = hit.index
          ChooseBrowserItem()
          return true
        end
      end
    end
    return true
  end
  if button == 1 then
    for _, tab in ipairs(header_hit_boxes) do
      if x >= tab.x and x < tab.x + tab.w and
          y >= tab.y and y < tab.y + tab.h then
        OpenView(tab.mode)
        return true
      end
    end
  end
  if view_mode == "inspector" then return false end
  if view_mode == "assembly" then
    if button ~= 1 then return false end
    for _, c in ipairs(assembly_hit_boxes) do
      if x >= c.x and x < c.x + c.w and y >= c.y and y < c.y + c.h then
        if c.kind == "action" then
          if c.action == "undo" or c.action == "redo" then
            UndoRedoAssembly(c.action == "redo")
          else
            local mods = (SDL.getKeyModifiers and SDL.getKeyModifiers()) or {}
            EditAssembly(c.action, mods.shift and 8 or 1)
          end
        elseif c.kind == "overview" then
          local size_of = function(id) return sprite_table:size(id) end
          local index = Layout.strip_pick(selected, size_of, x, c.x, c.w)
          if index then
            focus_id = selected[index].id
            local sw = GetViewerSize(TheApp.video)
            assembly_pan_x = Layout.center_strip(selected, size_of, index,
              sw, c.zoom)
            MarkDirty()
          end
        else
          FocusAssemblyIndex(c.index)
        end
        return true
      end
    end
    local _, sh = GetViewerSize(TheApp.video)
    local mods = (SDL.getKeyModifiers and SDL.getKeyModifiers()) or {}
    local index, overlap = Layout.assembly_pick(assembly_preview_rects,
      x, y, IndexOf(focus_id), assembly_mode == "layers" and mods.shift,
      header_height, sh - 109)
    if index then
      FocusAssemblyIndex(index)
      if assembly_mode == "layers" then
        local item = selected[index]
        local rect = assembly_preview_rects[index]
        if rect then
          -- Snapshot scale and down point; reflow during motion cannot create
          -- feedback or move the pointer relative to the dragged sprite.
          local sw, sh = GetViewerSize(TheApp.video)
          local min_x, min_y, max_x, max_y = Layout.assembly_bounds(selected,
            "layers", function(id) return sprite_table:size(id) end)
          local placement = Layout.assembly_placement(sw, sh, header_height,
            scale, min_x, min_y, max_x, max_y, "layers", assembly_pan_x)
          assembly_drag = Drag.begin(item, index, x, y, placement.scale)
          assembly_drag.placement = placement
          assembly_drag.min_x, assembly_drag.min_y = min_x, min_y
        end
      end
      if assembly_mode == "layers" and overlap > 1 then
        notice = "Overlapping layers " .. overlap .. ": Shift+click cycles below"
      end
      return true
    end
    return false
  end
  if view_mode == "animation" then
    if button ~= 1 then return false end
    for _, c in ipairs(animation_hit_boxes) do
      if x >= c.x and x < c.x + c.w and y >= c.y and y < c.y + c.h then
        animation_playing = false
        SelectAnimationFrame(c.index)
        return true
      end
    end
    return false
  end
  if view_mode ~= "sheet" or y < header_height then return false end
  if button ~= 1 and button ~= 3 then return false end
  for _, c in ipairs(hit_boxes) do
    if x >= c.x and x < c.x + c.w and y >= c.y and y < c.y + c.h then
      -- Mouse button events have no modifier argument. CorsixTH exposes the
      -- actual SDL keyboard modifiers; this also handles Shift held before
      -- opening the viewer. Right-click retains its original checkbox action.
      local mods = (SDL and SDL.getKeyModifiers and SDL.getKeyModifiers()) or {}
      if mods.shift then
        SelectRange(selection_anchor or c.id, c.id)
      elseif button == 3 or (mods.ctrl and button == 1) or x < c.x + 13 then
        ToggleSelection(c.id)
      else
        focus_id = c.id
        selection_anchor = c.id
        MarkDirty()
      end
      return true
    end
  end
  return false
end

local function DoMouseMove(_, x, y, dx, dy)
  if not assembly_drag then return false end
  local mods = (SDL.getKeyModifiers and SDL.getKeyModifiers()) or {}
  local nx, ny = Drag.position(assembly_drag, x, y, mods.ctrl)
  Assembly.set_offset(selected, assembly_drag.id, nx, ny)
  MarkDirty()
  return true
end

local function DoMouseUp(_, button, x, y)
  if button ~= 1 or not assembly_drag then return false end
  local mods = (SDL.getKeyModifiers and SDL.getKeyModifiers()) or {}
  local nx, ny = Drag.position(assembly_drag, x, y, mods.ctrl)
  Assembly.set_offset(selected, assembly_drag.id, nx, ny)
  CommitAssemblyDrag()
  return true
end

local function DoMouseWheel(_, x, y)
  if browser_kind and y ~= 0 then
    browser_cursor = math.max(1, math.min(#browser_results,
      browser_cursor - math.floor(y)))
    MarkDirty()
    return true
  end
  if view_mode == "sheet" and y ~= 0 then
    y_off = y_off + math.floor(y * 54)
    MarkDirty()
    return true
  end
  if view_mode == "assembly" and y ~= 0 and #selected > 0 then
    -- Wheel over the assembly is a focus navigator, matching J/K. The
    -- preview and stable component page reveal the focused item together.
    -- Bound large hardware-wheel deltas to avoid an accidental long sweep.
    local steps = math.min(8, math.max(1, math.floor(math.abs(y))))
    local direction = y > 0 and -1 or 1
    for _ = 1, steps do FocusSelected(direction) end
    return true
  end
  return need_draw
end

-- The viewer's only persistent chrome: compact mode selectors.  The contact
-- sheet remains full-width and the preview modes do not become docked panels.
local function DrawViewTabs(canvas, width)
  header_hit_boxes = {}
  local tabs = {{"sheet", "SHEET"}, {"inspector", "DETAIL"},
                {"assembly", "ASSEMBLY"}, {"animation", "FRAMES"}}
  -- On narrow screens the tabs get their own row rather than covering the
  -- page title.  At 320x200 all four remain visible and clickable.
  local compact = width < 520
  local tab_width = compact and math.min(75, math.floor((width - 8) / #tabs)) or 85
  local x0 = compact and math.max(2, math.floor((width - tab_width * #tabs) / 2))
    or math.max(4, width - tab_width * #tabs - 2)
  local tab_y = compact and 15 or 1
  for i, tab in ipairs(tabs) do
    local x = x0 + (i - 1) * tab_width
    local active = view_mode == tab[1]
    local line = canvas:mapRGB(74, 91, 100)
    local fill = active and canvas:mapRGB(52, 78, 91) or canvas:mapRGB(30, 33, 36)
    canvas:drawRect(line, x, tab_y, tab_width - 2, 13)
    canvas:drawRect(fill, x + 1, tab_y + 1, tab_width - 4, 11)
    font:draw(canvas, compact and
      (tab[1] == "assembly" and "BUILD" or tab[2]) or tab[2], x + 4, tab_y + 1)
    header_hit_boxes[#header_hit_boxes + 1] = {
      mode = tab[1], x = x, y = tab_y, w = tab_width - 2, h = 13
    }
  end
end

local function DrawNotice(canvas, sw, sh)
  if not notice then return end
  -- Keep assembly chips and animation frame IDs visible below the preview.
  canvas:drawRect(canvas:mapRGB(32, 39, 42), 0, header_height - 15, sw, 15)
  DrawFittedText(canvas, notice, 4, header_height - 13, sw - 8)
end

local function RenderHeader(canvas, width)
  -- Intentionally plain; the sprites are the content, not the UI chrome.
  canvas:drawRect(canvas:mapRGB(18, 18, 18), 0, 0, width, header_height)
  local path = sprite_table_paths[sprite_table_index]
  local sprite_w, sprite_h = sprite_table:size(focus_id)
  if width < 520 then
    DrawFittedText(canvas, "Sprite viewer  " .. path[2], 2, 1, width - 4)
    DrawFittedText(canvas, "Focus #" .. focus_id .. " " .. sprite_w .. "x" .. sprite_h ..
      "   checked " .. #selected, 2, 29, width - 4)
    DrawFittedText(canvas, "Click focus  box check  Shift-range  F1 help", 2, 42, width - 4)
  elseif width < 600 then
    font:draw(canvas, "Sprite viewer", 2, 1)
    DrawFittedText(canvas, "Click focus  box check  Shift-click range  F1 help", 2, 15, width - 4)
    DrawFittedText(canvas, path[2] .. "  " .. palette_name, 2, 28, width - 4)
    DrawFittedText(canvas, "Focus #" .. focus_id .. " " .. sprite_w .. "x" .. sprite_h ..
      "   zoom " .. scale .. "x  checked: " .. #selected, 2, 41, width - 4)
  else
    font:draw(canvas, "Sprite viewer", 2, 1)
    DrawFittedText(canvas,
      "Click focus   box check   Shift-click range   / find   T frames   F1 help", 2, 15, width - 4)
    DrawFittedText(canvas, table.concat(path, "/") .. "  " ..
      (is_complex and "complex" or "simple") .. "  " .. palette_name, 2, 28, width - 4)
    DrawFittedText(canvas, "Focus #" .. focus_id .. " " .. sprite_w .. "x" .. sprite_h ..
      "  zoom " .. scale .. "x   checked: " .. #selected ..
      "   P palette  Q close", 2, 41, width - 4)
  end
  if jump_mode then
    local prompt = (jump_mode == "sprite" and "Go #" or "Copies ") .. jump_text .. "_ Enter/Esc"
    canvas:drawRect(canvas:mapRGB(18, 18, 18), 0, header_height - 16, width, 16)
    DrawFittedText(canvas, prompt, 3, header_height - 14, width - 6)
  end
end

-- Thin rectangles keep highlight edges crisp at native pixel size. The focus
-- cue is a frame, never a tint over source sprite pixels. Checked state is a
-- separate checkbox; the two states must remain legible independently.
local function DrawOutline(canvas, colour, x, y, width, height)
  if width <= 1 or height <= 1 then return end
  canvas:drawRect(colour, x, y, width, 1)
  canvas:drawRect(colour, x, y + height - 1, width, 1)
  canvas:drawRect(colour, x, y, 1, height)
  canvas:drawRect(colour, x + width - 1, y, 1, height)
end

local function RenderSheet(canvas, sw, sh)
  hit_boxes = {}
  local cells, rows = ClampScroll(sw, sh)
  local first, last = Layout.visible_range(rows, y_off, header_height, sh)
  for index = first, last do
    local c = cells[index]
    local y = c.y + y_off
    if y >= header_height and y < sh and y + c.h > header_height then
      local checked = selected_lookup[c.id] == true
      local focused = c.id == focus_id
      -- Focus is a full label-row cue; checked is a distinct marked box.
      -- Never shade the actual source sprite image beneath the row.
      if focused then
        canvas:drawRect(canvas:mapRGB(43, 66, 76), c.x, y,
          math.max(1, c.w - 2), c.label_h + 3)
        canvas:drawRect(canvas:mapRGB(119, 185, 193), c.x, y, 2, c.label_h + 3)
      end
      local border = checked and canvas:mapRGB(124, 207, 180) or
        canvas:mapRGB(125, 125, 125)
      canvas:drawRect(border, c.x + 2, y + 2, 9, 9)
      canvas:drawRect(canvas:mapRGB(18, 18, 18), c.x + 3, y + 3, 7, 7)
      if checked then
        canvas:drawRect(border, c.x + 4, y + 4, 5, 5)
      end
      local w, h = sprite_table:size(c.id)
      local marker = focused and ">" or " "
      font:draw(canvas, marker .. "#" .. c.id .. " " .. w .. "x" .. h, c.x + 12, y)
      sprite_table:draw(canvas, c.id, c.x, y + c.label_h + 4, {scaleFactor = scale})
      hit_boxes[#hit_boxes + 1] = {id = c.id, x = c.x, y = y, w = c.w, h = c.h}
    end
  end
  RenderHeader(canvas, sw)
end

local function AssemblyBounds()
  return Layout.assembly_bounds(selected, assembly_mode,
    function(id) return sprite_table:size(id) end)
end

local function RenderAssembly(canvas, sw, sh)
  assembly_hit_boxes = {}
  assembly_preview_rects = {}
  canvas:drawRect(canvas:mapRGB(18, 18, 18), 0, 0, sw, header_height)
  if sw < 520 then
    font:draw(canvas, "Sprite assembly", 2, 2)
    DrawFittedText(canvas, assembly_mode .. "  " .. #selected ..
      " parts   focus #" .. focus_id, 2, 29, sw - 4)
    DrawFittedText(canvas, "Click / drag layer  F1 help", 2, 42, sw - 4)
  elseif sw < 600 then
    font:draw(canvas, "Sprite assembly", 2, 2)
    DrawFittedText(canvas, "Click / drag layer  M mode  F1", 2, 16, sw - 4)
    DrawFittedText(canvas, "Ctrl+S save  Ctrl+O load  V gallery", 2, 30, sw - 4)
  else
    font:draw(canvas, "Sprite assembly", 2, 2)
    local hint = assembly_mode == "layers" and
      "Drag layers  Ctrl snap 8px  Shift+click cycles  F1" or
      "Click artwork or overview  J/K/wheel focus  PgUp/Dn  F1"
    DrawFittedText(canvas, hint, 2, 16, sw - 4)
    DrawFittedText(canvas, "Ctrl+S save  Ctrl+O load  V gallery  X capture", 2, 30, sw - 4)
  end
  if #selected == 0 then
    font:draw(canvas, "No sprites checked. Press V, tick some sprites, then return.", 8, 78)
    return
  end
  local min_x, min_y, max_x, max_y = AssemblyBounds()
  local placement
  if assembly_drag and assembly_mode == "layers" then
    -- Freeze the visual origin during a drag. Otherwise changing the current
    -- minimum offset would re-centre the whole composite under the pointer.
    placement = assembly_drag.placement
    min_x, min_y = assembly_drag.min_x, assembly_drag.min_y
  else
    placement = Layout.assembly_placement(sw, sh, header_height,
      scale, min_x, min_y, max_x, max_y, assembly_mode, assembly_pan_x)
  end
  local composite_w, composite_h = placement.width, placement.height
  local fit = placement.scale
  assembly_min_pan_x, assembly_pan_x = placement.pan_min, placement.pan_x
  local active_idx = IndexOf(focus_id) or 1
  local size_of = function(id) return sprite_table:size(id) end
  assembly_preview_rects = Layout.assembly_rects(selected, assembly_mode,
    size_of, placement, min_x, min_y)
  for i, item in ipairs(selected) do
    local rect = assembly_preview_rects[i]
    if assembly_mode == "strip" then
      local w = sprite_table:size(item.id)
      for copy = 0, item.repeat_count - 1 do
        sprite_table:draw(canvas, item.id, rect.x + copy * w * fit,
          rect.y, {scaleFactor = fit})
      end
    else
      sprite_table:draw(canvas, item.id, rect.x, rect.y, {scaleFactor = fit})
    end
  end
  local focused_rect = assembly_preview_rects[active_idx]
  local active_rect = focused_rect and {focused_rect.x, focused_rect.y,
    focused_rect.w, focused_rect.h}
  -- Emphasise the component being edited, including all repeated strip copies.
  -- This overlay belongs solely to the inspector: no original pixels change.
  if active_rect then
    DrawOutline(canvas, canvas:mapRGB(132, 199, 206),
      active_rect[1] - 1, active_rect[2] - 1,
      active_rect[3] + 2, active_rect[4] + 2)
  end
  -- Native-looking edit buttons use the same commands as keyboard input.
  -- The toolbar overlays only the reserved inspector footer, not game pixels.
  canvas:drawRect(canvas:mapRGB(18, 18, 18), 0, sh - 108, sw, 29)
  for _, action in ipairs(Layout.assembly_controls(sw, sh, assembly_mode)) do
    local enabled = action.action == "undo" and History.can_undo(assembly_history)
      or action.action == "redo" and History.can_redo(assembly_history)
      or (action.action ~= "undo" and action.action ~= "redo" and
          Assembly.can(selected, focus_id, action.action))
    canvas:drawRect(canvas:mapRGB(enabled and 91 or 56,
      enabled and 128 or 60, enabled and 139 or 64),
      action.x, action.y, action.w, action.h)
    canvas:drawRect(canvas:mapRGB(22, 26, 28),
      action.x + 1, action.y + 1, action.w - 2, action.h - 2)
    DrawFittedText(canvas, action.label, action.x + 6, action.y + 5, action.w - 12)
    if enabled then
      assembly_hit_boxes[#assembly_hit_boxes + 1] = {
        kind = "action", action = action.action,
        x = action.x, y = action.y, w = action.w, h = action.h,
      }
    end
  end
  -- A long checked set must never become a clipped single line. Keep a
  -- short, clickable window of component IDs near the focused component.
  local desc = assembly_mode .. "  " .. composite_w .. "x" .. composite_h ..
    "  display " .. fit .. "x  checked " .. #selected
  if assembly_min_pan_x < 0 then
    desc = desc .. "  pan " .. -assembly_pan_x .. "/" .. -assembly_min_pan_x
  end
  DrawFittedText(canvas, desc, 8, sh - 75, sw - 16)
  local active = selected[active_idx]
  local details = "Focus #" .. active.id .. "  item " .. active_idx .. "/" .. #selected
  if assembly_mode == "strip" then
    details = details .. "  copies " .. active.repeat_count
  else
    details = details .. "  offset (" .. active.dx .. "," .. active.dy .. ")" ..
      "  layer " .. active_idx .. "/" .. #selected ..
      (assembly_drag and "  DRAG (Esc cancel)" or "")
  end
  local _, _, page_number, page_count = Layout.assembly_page(
    active_idx, #selected, AssemblyPageCapacity())
  details = details .. "  page " .. page_number .. "/" .. page_count ..
    "  history " .. #assembly_history.past .. "/" .. #assembly_history.future
  DrawFittedText(canvas, details, 8, sh - 59, sw - 16)
  local cell_w = sw < 520 and 56 or 70
  local visible = AssemblyPageCapacity()
  local first, last, page, pages = Layout.assembly_page(active_idx, #selected, visible)
  local grey = canvas:mapRGB(115, 115, 115)
  local ink = canvas:mapRGB(132, 199, 206)
  local dark = canvas:mapRGB(18, 18, 18)
  -- Compact positional overview: dim track = entire assembly, muted teal =
  -- visible viewport, warm marker = active component. Click to locate it.
  if assembly_mode == "strip" then
    local size_of = function(id) return sprite_table:size(id) end
    local overview = Layout.strip_overview(selected, size_of, active_idx,
      sw, fit, assembly_pan_x, 8, sw - 16)
    if overview then
      local y = sh - 45
      canvas:drawRect(canvas:mapRGB(65, 65, 65),
        overview.x, y, overview.width, 7)
      canvas:drawRect(canvas:mapRGB(91, 128, 139),
        overview.view_x, y, overview.view_width, 7)
      canvas:drawRect(canvas:mapRGB(226, 180, 100),
        overview.focus_x, y, overview.focus_width, 7)
      assembly_hit_boxes[#assembly_hit_boxes + 1] =
        {kind = "overview", x = overview.x, y = y - 3,
         w = overview.width, h = 12, zoom = fit}
    end
  end
  local row_y = sh - 34
  for i = first, last do
    local item = selected[i]
    local x = 20 + (i - first) * cell_w
    canvas:drawRect(i == active_idx and ink or grey, x, row_y, cell_w - 3, 23)
    canvas:drawRect(dark, x + 1, row_y + 1, cell_w - 5, 21)
    local label = "#" .. item.id ..
      (item.repeat_count > 1 and "x" .. item.repeat_count or "")
    DrawFittedText(canvas, label, x + 4, row_y + 5, cell_w - 10)
    assembly_hit_boxes[#assembly_hit_boxes + 1] =
      {index = i, x = x, y = row_y, w = cell_w - 3, h = 23}
  end
  if page > 1 then
    canvas:drawRect(ink, 2, row_y, 15, 23)
    canvas:drawRect(dark, 3, row_y + 1, 13, 21)
    font:draw(canvas, "<", 5, row_y + 5)
    assembly_hit_boxes[#assembly_hit_boxes + 1] =
      {index = Layout.assembly_page_target(active_idx, #selected, visible, -1),
       x = 2, y = row_y, w = 15, h = 23}
  end
  if page < pages then
    canvas:drawRect(ink, sw - 17, row_y, 15, 23)
    canvas:drawRect(dark, sw - 16, row_y + 1, 13, 21)
    font:draw(canvas, ">", sw - 14, row_y + 5)
    assembly_hit_boxes[#assembly_hit_boxes + 1] =
      {index = Layout.assembly_page_target(active_idx, #selected, visible, 1),
       x = sw - 17, y = row_y, w = 15, h = 23}
  end
  if jump_mode then
    font:draw(canvas, "Repeat count: " .. jump_text .. "_  [Enter/Esc]", 8, sh - 95)
  end
end

-- No timeline is shown in the contact sheet. This frame strip appears only
-- when explicitly requested, following XCC Mixer's separate SHP video viewer.
local function RenderAnimation(canvas, sw, sh)
  animation_hit_boxes = {}
  local ink = canvas:mapRGB(220, 220, 220)
  local grey = canvas:mapRGB(105, 105, 105)
  canvas:drawRect(canvas:mapRGB(18, 18, 18), 0, 0, sw, header_height)
  local path = sprite_table_paths[sprite_table_index]
  if sw < 520 then
    DrawFittedText(canvas, "Frame preview  " .. path[2], 2, 2, sw - 4)
    DrawFittedText(canvas, "Space play  Arrows step  T back", 2, 29, sw - 4)
    DrawFittedText(canvas, "[/] FPS  L loop  H align  F1 help", 2, 42, sw - 4)
  elseif sw < 600 then
    font:draw(canvas, "Preview  T: back  Space: play", 2, 2)
    font:draw(canvas, "Arrows: step  [/]: FPS  L: loop", 2, 16)
    font:draw(canvas, "- /=: zoom  H: align  " .. path[2], 2, 30)
  else
    font:draw(canvas, "Frame preview", 2, 2)
    font:draw(canvas, "[/]: FPS  -/=: zoom  L: loop/once/pingpong  H: align  Q: exit", 2, 16)
    font:draw(canvas, table.concat(path, "/") .. "  " .. palette_name ..
      "  (user-chosen sequence; timing is not stored in DAT/TAB)", 2, 30)
  end
  if #selected == 0 then
    font:draw(canvas, "No frames checked. Press T, tick sprites in the gallery, then press T.", 8, 86)
    return
  end

  animation_index = math.min(animation_index, #selected)
  local max_w, max_h = 1, 1
  for _, item in ipairs(selected) do
    local w, h = sprite_table:size(item.id)
    max_w, max_h = math.max(max_w, w), math.max(max_h, h)
  end
  local strip_top = sh - 50
  local preview_top = header_height + 12
  local space_h = math.max(1, strip_top - preview_top - 26)
  local fit = math.max(1, math.min(animation_zoom,
    math.floor((sw - 24) / max_w), math.floor(space_h / max_h)))
  local start_x = math.max(0, math.floor((sw - max_w * fit) / 2))
  local start_y = preview_top + math.max(0, math.floor((space_h - max_h * fit) / 2))
  local active = selected[animation_index]
  local w, h = sprite_table:size(active.id)
  local align_y = 0
  if animation_anchor == "bottom" then
    align_y = (max_h - h) * fit
  elseif animation_anchor == "centre" then
    align_y = math.floor((max_h - h) * fit / 2)
  end
  -- Never reconstruct or blend neighbouring frames. Use the original sprite
  -- drawing API, preserving its transparency and selected palette.
  sprite_table:draw(canvas, active.id, start_x, start_y + align_y,
    {scaleFactor = fit})

  local status = animation_playing and "Playing" or "Paused"
  local status_format = sw < 600 and "%s %d/%d #%d %dFPS %s" or
    "%s   %d/%d   sprite #%d   %dx%d   %d FPS   %s   %s"
  if sw < 600 then
    font:draw(canvas, string.format(status_format, status, animation_index,
      #selected, active.id, animation_fps, animation_mode), 6, header_height - 13)
  else
    font:draw(canvas, string.format(status_format, status, animation_index,
      #selected, active.id, w, h, animation_fps, animation_mode,
      animation_anchor), 6, header_height - 13)
  end
  if max_w * fit > sw or max_h * fit > space_h then
    font:draw(canvas, "Large sprite: preview may be clipped", 8, strip_top - 14)
  end

  -- Filmstrip shows only sprite IDs, not an intrusive second contact sheet.
  -- The visible range follows the active frame for longer selected sequences.
  local cell_w = 49
  local visible = math.max(1, math.floor((sw - 16) / cell_w))
  local first = math.max(1, math.min(animation_index - math.floor(visible / 2),
                                    #selected - visible + 1))
  local last = math.min(#selected, first + visible - 1)
  local y = sh - 36
  for i = first, last do
    local x = 8 + (i - first) * cell_w
    local active_cell = (i == animation_index)
    canvas:drawRect(active_cell and ink or grey, x, y, cell_w - 3, 22)
    canvas:drawRect(canvas:mapRGB(18, 18, 18), x + 1, y + 1, cell_w - 5, 20)
    font:draw(canvas, "#" .. selected[i].id, x + 3, y + 5)
    if active_cell then
      canvas:drawRect(ink, x, y + 22, cell_w - 3, 2)
    end
    animation_hit_boxes[#animation_hit_boxes + 1] = {
      index = i, x = x, y = y, w = cell_w - 3, h = 24
    }
  end
  if first > 1 then font:draw(canvas, "<", 0, y + 5) end
  if last < #selected then font:draw(canvas, ">", sw - 10, y + 5) end
end

-- One-sprite detail mode is intentionally not another selection mechanism.
-- It shows original size, decoding and palette together with a large preview.
local function RenderInspector(canvas, sw, sh)
  canvas:drawRect(canvas:mapRGB(18, 18, 18), 0, 0, sw, header_height)
  local path = sprite_table_paths[sprite_table_index]
  if sw < 520 then
    DrawFittedText(canvas, "Sprite detail  " .. path[2], 2, 2, sw - 4)
    DrawFittedText(canvas, "Arrows step  Shift+arrows pan", 2, 29, sw - 4)
    DrawFittedText(canvas, "-/= zoom  H grid  I back  F1 help", 2, 42, sw - 4)
  else
    font:draw(canvas, "Sprite detail", 2, 2)
    DrawFittedText(canvas, "Arrows: sprite  Shift+arrows: pan  -/=: zoom  H grid  I back", 2, 16, sw - 4)
    DrawFittedText(canvas, table.concat(path, "/") .. "  " ..
      (is_complex and "complex" or "simple") .. "  " .. palette_name, 2, 30, sw - 4)
  end
  local w, h = sprite_table:size(focus_id)
  local fit = math.max(1, math.min(inspector_zoom,
    math.floor((sw - 20) / math.max(1, w)),
    math.floor((sh - header_height - 90) / math.max(1, h))))
  local x = math.floor((sw - w * fit) / 2) + inspector_pan_x
  local y = header_height + math.floor((sh - header_height - 66 - h * fit) / 2) + inspector_pan_y
  if w == 0 or h == 0 then
    font:draw(canvas, "This entry has no drawable pixels (0 x 0).", 12, math.floor(sh / 2))
  end
  if inspector_checkerboard and w > 0 and h > 0 then
    local square = math.max(6, 8 * fit)
    local dark = canvas:mapRGB(67, 67, 67)
    local light = canvas:mapRGB(107, 107, 107)
    for yy = 0, h * fit - 1, square do
      for xx = 0, w * fit - 1, square do
        canvas:drawRect((math.floor(xx/square) + math.floor(yy/square)) % 2 == 0 and dark or light,
          x + xx, y + yy, math.min(square, w * fit - xx), math.min(square, h * fit - yy))
      end
    end
  end
  if w > 0 and h > 0 then
    sprite_table:draw(canvas, focus_id, x, y, {scaleFactor = fit})
  end
  local label = string.format("#%d / %d     %d x %d px     %dx     %s",
    focus_id, #sprite_table - 1, w, h, fit,
    selected_lookup[focus_id] and "[x] selected" or "[ ] not selected")
  canvas:drawRect(canvas:mapRGB(28, 32, 35), 0, sh - 47, sw, 47)
  font:draw(canvas, label, 8, sh - 40)
  font:draw(canvas, "Actual sprite pixels. No smoothing or reconstruction.", 8, sh - 25)
end

local function RenderBrowser(canvas, sw, sh)
  if not browser_kind then return end
  browser_hit_boxes = {}
  local height = math.max(84, math.min(220, sh - 70))
  local width = math.min(440, sw - 12)
  local left, top = math.floor((sw - width) / 2), math.max(20, math.floor((sh - height) / 3))
  local edge = canvas:mapRGB(85, 104, 113)
  canvas:drawRect(edge, left, top, width, height)
  canvas:drawRect(canvas:mapRGB(25, 28, 31), left + 1, top + 1, width - 2, height - 2)
  local title = browser_kind == "table" and "Find sprite table" or "Choose palette"
  font:draw(canvas, title .. "     [Esc to cancel]", left + 8, top + 8)
  canvas:drawRect(canvas:mapRGB(47, 54, 58), left + 7, top + 24, width - 14, 19)
  font:draw(canvas, "> " .. browser_query .. "_", left + 12, top + 27)
  local visible = math.max(1, math.floor((height - 57) / 17))
  local first = math.max(1, math.min(browser_cursor - math.floor(visible / 2),
                                     #browser_results - visible + 1))
  for i = first, math.min(#browser_results, first + visible - 1) do
    local hit = browser_results[i]
    local y = top + 49 + (i - first) * 17
    if i == browser_cursor then
      canvas:drawRect(canvas:mapRGB(52, 78, 91), left + 6, y - 1, width - 12, 16)
    end
    font:draw(canvas, hit.text, left + 12, y + 1)
    browser_hit_boxes[#browser_hit_boxes + 1] = {
      index = i, x = left + 6, y = y - 1, w = width - 12, h = 16
    }
  end
  if #browser_results == 0 then
    font:draw(canvas, "No matches", left + 12, top + 57)
  end
  font:draw(canvas, string.format("%d matches  -  arrows / Enter / click",
    #browser_results), left + 8, top + height - 14)
end

local function RenderHelp(canvas, sw, sh)
  if not help_open then return end
  local w = math.min(495, sw - 16)
  local h = math.min(306, sh - 40)
  local x, y = math.floor((sw - w)/2), math.floor((sh - h)/2)
  canvas:drawRect(canvas:mapRGB(85, 104, 113), x, y, w, h)
  canvas:drawRect(canvas:mapRGB(25, 28, 31), x + 1, y + 1, w - 2, h - 2)
  local lines = {
    "SPRITE VIEWER  /  KEYBOARD REFERENCE",
    "Browse:   A/D tables   / find table   Shift+P find palette",
    "          W/S scroll   G jump   -/= zoom   C decode",
    "          P next palette   F auto palette   B background",
    "Select:   click focus   tick box or Ctrl+click toggle",
    "          Shift+click range   Ctrl+A all   Ctrl+I invert",
    "          U clear   Space toggle   Shift+J/K range",
    "Detail:   I preview   Left/Right step   H checkerboard",
    "          Shift+arrows pan large sprites   0 recenter",
    "Assembly: V toggle   M strip/layers   ,/. reorder",
    "          J/K focus  PgUp/Dn pages  Home/End ends",
    "          Click overview track to seek wide strips",
    "          Click artwork to focus  Shift+click cycles overlap",
    "          Drag layer  Ctrl snap 8px  Esc cancels drag",
    "          Edit buttons: order, copies, XY offsets, reset",
    "          Undo Ctrl+Z   Redo Ctrl+Y / Ctrl+Shift+Z",
    "          arrows pan/nudge   Shift+arrows x8   N copies",
    "Frames:   T toggle   Space play   Left/Right step",
    "          [/]: FPS   L loop/once/pingpong   H align",
    "Files:    Ctrl+S save recipe   Ctrl+O load recipe",
    "          X screenshot   Q close viewer",
    "",
    "Esc / click: close help.  Original game files stay read-only.",
  }
  local _, fonth = font:sizeOf("X")
  local step = math.max(12, fonth + 3)
  local per_page = math.max(1, math.floor((h - 34) / step))
  local total_pages = math.max(1, math.ceil(#lines / per_page))
  help_page = math.min(help_page, total_pages)
  local first = (help_page - 1) * per_page + 1
  canvas:drawRect(canvas:mapRGB(52, 78, 91), x + 5, y + 5, w - 10, 16)
  for i = first, math.min(#lines, first + per_page - 1) do
    DrawFittedText(canvas, lines[i], x + 9, y + 9 + (i-first)*step, w - 18)
  end
  font:draw(canvas, string.format("%d/%d  Up/Down: page  Esc: close",
    help_page, total_pages), x + 8, y + h - 15)
end

local function Render(canvas)
  local sw, sh = GetViewerSize(canvas)
  if view_mode == "sheet" then
    RenderSheet(canvas, sw, sh)
  elseif view_mode == "assembly" then
    RenderAssembly(canvas, sw, sh)
  elseif view_mode == "animation" then
    RenderAnimation(canvas, sw, sh)
  else
    RenderInspector(canvas, sw, sh)
  end
  DrawViewTabs(canvas, sw)
  DrawNotice(canvas, sw, sh)
  RenderBrowser(canvas, sw, sh)
  RenderHelp(canvas, sw, sh)
end

local function SaveScreenshot(canvas)
  local root = TheApp.screenshot_dir
  if type(root) ~= "string" or root == "" then
    return false, "Screenshots directory is not configured"
  end
  local path = sprite_table_paths[sprite_table_index]
  local sep = root:match("[/\\]$") and "" or package.config:sub(1, 1)
  local basename = string.format("SpriteViewer_%s_%s_%s",
    path[1]:gsub("[^%w]", ""), path[2]:gsub("[^%w]", ""),
    os.date("%Y%m%d-%H%M%S"))
  for i = 0, 999 do
    local filename = root .. sep .. basename .. "_" .. i .. ".png"
    local handle = io.open(filename, "rb")
    if handle then
      handle:close()
    else
      local ok, result, err = pcall(canvas.takeScreenshot, canvas, filename)
      if not ok then return false, tostring(result) end
      if not result then return false, tostring(err or "Screenshot failed") end
      return true, filename
    end
  end
  return false, "No available screenshot filename"
end

local function DoFrame(app)
  local canvas = app.video
  canvas:startFrame()
  if need_draw then
    need_draw = app.config.track_fps
    canvas:fillColour(background_colours[bg_colour_index])
    Render(canvas)
  end
  canvas:endFrame()
  if screenshot_requested then
    screenshot_requested = false
    local ok, message = SaveScreenshot(canvas)
    notice = ok and ("Screenshot: " .. DisplayFilename(message)) or
      ("Screenshot failed: " .. message)
    MarkDirty()
  end
end

local function DoTimer()
  if view_mode == "animation" and animation_playing then
    local now = GetTimeMs()
    local interval = 1000 / animation_fps
    if animation_last_tick == nil then animation_last_tick = now end
    local elapsed = now - animation_last_tick
    if elapsed < 0 then
      -- SDL tick counter wrapped; start timing again.
      animation_last_tick = now
    elseif elapsed >= interval then
      -- Catch up when a timer event is delayed, but don't freeze after long
      -- pauses or window focus changes.  No frame blending/interpolation.
      local advances = math.min(8, math.floor(elapsed / interval))
      for _ = 1, advances do
        if not animation_playing then break end
        AdvanceAnimationFrame()
      end
      if advances == 8 then
        animation_last_tick = now
      else
        animation_last_tick = animation_last_tick + advances * interval
      end
      MarkDirty()
    end
  end
  if view_mode == "sheet" then
    if wdown then y_off = y_off + 32; MarkDirty() end
    if sdown then y_off = y_off - 32; MarkDirty() end
  end
  return need_draw
end

-- The native SDL dispatcher sends these events even while the debug viewer
-- owns the input handlers. Do not forward them to the game underneath.
-- A resize invalidates the cached contact-sheet positions.
local function DoWindowResize()
  CancelAssemblyDrag()
  sheet_layout_cache = nil
  MarkDirty()
  return true
end

local function DoActive()
  -- Window activation changes may lose the matching mouse-up event.
  -- Discard any in-progress preview instead of leaving an edit armed.
  CancelAssemblyDrag()
  MarkDirty()
  return false
end

local function IgnoreViewerEvent()
  return false
end

local function open()
  if is_open then return end
  is_open = true
  ResetAnimation()
  view_mode = "sheet"
  old_gfx_cache = gfx.cache.tabled
  gfx.cache.tabled = sprite_viewer_gfx_cache
  font = gfx:loadFontAndSpriteTable("QData", "Font00V")
  old_event_handlers = TheApp.eventHandlers
  TheApp.eventHandlers = {
    frame = DoFrame,
    keydown = DoKey,
    keyup = DoKeyUp,
    timer = DoTimer,
    textinput = DoTextInput,
    buttondown = DoMouseDown,
    buttonup = DoMouseUp,
    motion = DoMouseMove,
    active = DoActive,
    window_resize = DoWindowResize, -- legacy alias for older event dispatchers
    window_resized = DoWindowResize, -- CorsixTH SDL3 dispatcher
    window_pixel_size_changed = DoWindowResize,
    window_display_scale_changed = DoWindowResize,
    mousewheel = DoMouseWheel,
  }
  MarkDirty()
end

return open
