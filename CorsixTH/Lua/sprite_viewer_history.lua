-- Copyright (c) 2026 Sprite Viewer contributors.
-- SPDX-License-Identifier: MIT
-- Bounded undo/redo for assembly edits. Selection membership is managed by
-- sprite_viewer_selection.lua and invalidates this history at the UI boundary.
-- No SDL or game-data dependency; snapshots are owned by this module.
local History = {}

local function copy_items(items)
  local result = {}
  for i, item in ipairs(items) do
    result[i] = {id = item.id, dx = item.dx, dy = item.dy,
                 repeat_count = item.repeat_count}
  end
  return result
end

local function snapshot(items, focus, action)
  return {items = copy_items(items), focus = focus, action = action}
end

local function push(stack, snap, limit)
  if #stack == limit then table.remove(stack, 1) end
  stack[#stack + 1] = snap
end

function History.new(limit)
  limit = math.floor(tonumber(limit) or 32)
  return {limit = math.min(64, math.max(1, limit)), past = {}, future = {}}
end

function History.clear(history)
  history.past, history.future = {}, {}
end

function History.can_undo(history) return #history.past > 0 end
function History.can_redo(history) return #history.future > 0 end

function History.lookup(items)
  local result = {}
  for _, item in ipairs(items) do result[item.id] = true end
  return result
end

-- No-op and rejected edits do not consume history or invalidate redo.
-- Callbacks must return false without changing items when rejecting an edit.
function History.perform(history, items, focus, action, callback)
  local before = snapshot(items, focus, action)
  if not callback() then return false end
  push(history.past, before, history.limit)
  history.future = {}
  return true
end

function History.undo(history, items, focus)
  local previous = table.remove(history.past)
  if not previous then return nil end
  push(history.future, snapshot(items, focus, previous.action), history.limit)
  return copy_items(previous.items), previous.focus, previous.action
end

function History.redo(history, items, focus)
  local next_state = table.remove(history.future)
  if not next_state then return nil end
  push(history.past, snapshot(items, focus, next_state.action), history.limit)
  return copy_items(next_state.items), next_state.focus, next_state.action
end

return History
