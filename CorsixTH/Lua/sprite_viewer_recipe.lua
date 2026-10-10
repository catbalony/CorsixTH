-- Copyright (c) 2026 Sprite Viewer contributors.
-- SPDX-License-Identifier: MIT
-- Sidecar assembly codec and transactional file IO.
-- No references to TheApp, SDL or graphics state: independently testable.

local Recipe = {}
local VERSION = "SVR1"

function Recipe.path(root, dir, name, sep)
  if type(root) ~= "string" or root == "" then
    return nil, "No Screenshots directory configured"
  end
  sep = root:match("[/\\]$") and "" or (sep or package.config:sub(1, 1))
  return root .. sep .. ("SpriteViewer_%s_%s.svr"):format(
    dir:gsub("[^%w]", ""), name:gsub("[^%w]", ""))
end

function Recipe.serialize(dir, name, complex, mode, selected)
  local lines = {table.concat({VERSION, dir, name,
    complex and "complex" or "simple", mode}, "\t")}
  for _, item in ipairs(selected) do
    lines[#lines + 1] = string.format("%d\t%d\t%d\t%d",
      item.id, item.dx, item.dy, item.repeat_count)
  end
  return table.concat(lines, "\n") .. "\n"
end

function Recipe.parse(blob, dir, name, complex, sprite_count)
  if type(blob) ~= "string" or #blob > 32768 then
    return nil, "Recipe exceeds 32 KiB"
  end
  local lines = {}
  for line in blob:gmatch("([^\r\n]+)") do lines[#lines + 1] = line end
  if #lines == 0 or #lines > 4097 then return nil, "Invalid recipe length" end
  local ver, actual_dir, actual_name, format, mode = lines[1]:match(
    "^([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)$")
  if ver ~= VERSION then return nil, "Unsupported recipe version" end
  if actual_dir ~= dir or actual_name ~= name then
    return nil, "Recipe belongs to another sprite table"
  end
  if format ~= (complex and "complex" or "simple") then
    return nil, "Recipe expects a different decoding mode"
  end
  if mode ~= "layers" and mode ~= "strip" then
    return nil, "Invalid assembly mode"
  end
  local parsed, lookup = {}, {}
  for i = 2, #lines do
    local id, dx, dy, copies = lines[i]:match(
      "^(%-?%d+)\t(%-?%d+)\t(%-?%d+)\t(%d+)$")
    id, dx, dy, copies = tonumber(id), tonumber(dx), tonumber(dy), tonumber(copies)
    if not id or id < 0 or id >= sprite_count or
        not dx or math.abs(dx) > 4096 or not dy or math.abs(dy) > 4096 or
        not copies or copies < 1 or copies > 99 or lookup[id] then
      return nil, "Invalid entry at line " .. i
    end
    lookup[id] = true
    parsed[#parsed + 1] = {id = id, dx = dx, dy = dy, repeat_count = copies}
  end
  return {items = parsed, lookup = lookup, mode = mode}
end

-- Confirming an overwrite is a caller/UI concern. Return needs_confirmation
-- instead of writing until the caller explicitly confirms. Previous contents
-- are preserved as .bakN, including on Windows (where os.rename does not
-- replace existing files). The original game's resources are never opened.
function Recipe.save(path, value, confirm)
  local prev = io.open(path, "rb")
  local previous
  if prev then previous = prev:read("*a"); prev:close() end
  if previous == value then return true, "Already saved", false end
  if previous and not confirm then
    return false, "File exists. Ctrl+S again to replace your saved recipe.", true
  end

  local tmp = path .. ".tmp"
  local output, why = io.open(tmp, "wb")
  if not output then return false, "Save failed: " .. tostring(why), false end
  local ok, write_err = output:write(value)
  local close_ok, close_err = output:close()
  if not ok or not close_ok then
    os.remove(tmp)
    return false, "Save failed: " .. tostring(write_err or close_err), false
  end

  local backup
  if previous then
    for i = 1, 99 do
      local candidate = path .. ".bak" .. i
      local check = io.open(candidate, "rb")
      if check then check:close() else backup = candidate; break end
    end
  end
  if previous and not backup then
    os.remove(tmp)
    return false, "Save failed: too many existing recipe backups", false
  end
  local backup_ok, backup_err = true, nil
  if backup then backup_ok, backup_err = os.rename(path, backup) end
  if not backup_ok then
    os.remove(tmp)
    return false, "Save failed: " .. tostring(backup_err), false
  end
  local replaced, rename_err = os.rename(tmp, path)
  if not replaced then
    os.remove(tmp)
    local restored = not backup or os.rename(backup, path)
    return false, "Save failed: " .. tostring(rename_err) ..
      (restored and "" or " (previous file retained as backup)"), false
  end
  return true, "Saved", false
end

function Recipe.load(path, dir, name, complex, sprite_count)
  local fh, why = io.open(path, "rb")
  if not fh then return nil, "Load failed: " .. tostring(why) end
  local blob = fh:read(32769) or ""
  fh:close()
  local parsed, err = Recipe.parse(blob, dir, name, complex, sprite_count)
  if not parsed then return nil, "Recipe not loaded: " .. err end
  return parsed
end

return Recipe
