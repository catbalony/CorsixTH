local Recipe = require('sprite_viewer_recipe')
local rows = {
  {id = 1, dx = -15, dy = 4, repeat_count = 2},
  {id = 9, dx = 0, dy = 0, repeat_count = 1},
}
local data = Recipe.serialize('Data', 'PANEL04V', true, 'layers', rows)
local result, err = Recipe.parse(data, 'Data', 'PANEL04V', true, 28)
assert(result and not err)
assert(#result.items == 2 and result.items[1].dx == -15)
assert(result.lookup[1] and result.lookup[9] and not result.lookup[8])
assert(result.mode == 'layers')
local function rejects(payload, expected)
  local parsed, msg = Recipe.parse(payload, 'Data', 'PANEL04V', true, 28)
  assert(not parsed and msg:find(expected, 1, true), tostring(msg))
end
rejects(data:gsub('SVR1', 'SVR0', 1), 'version')
rejects(data:gsub('PANEL04V', 'PANEL02V', 1), 'another sprite table')
rejects(data:gsub('complex', 'simple', 1), 'decoding')
rejects(data:gsub('layers', 'explode', 1), 'assembly mode')
rejects(data .. '1\t0\t0\t1\n', 'line 4')
rejects(data .. '28\t0\t0\t1\n', 'line 4')
rejects(data .. '7\t4097\t0\t1\n', 'line 4')
rejects(data .. '7\t0\t0\t100\n', 'line 4')
rejects(data .. string.rep('0', 128 * 1024 + 1), '128 KiB')
local full, no_dir = Recipe.path('', 'Data', 'PANEL04V')
assert(not full and no_dir:find('Screenshots'))
assert(Recipe.path('tmp/', 'Data', 'PANEL04V') == 'tmp/SpriteViewer_Data_PANEL04V.svr')
local path = 'tests/sprite_viewer/tmp_codec_test.svr'
os.remove(path)
for n = 1, 4 do os.remove(path .. '.bak' .. n) end
local ok, message, confirmation = Recipe.save(path, data, false)
assert(ok and message == 'Saved' and not confirmation)
ok, message, confirmation = Recipe.save(path, data, false)
assert(ok and message == 'Already saved' and not confirmation)
ok, message, confirmation = Recipe.save(path, data .. '\n', false)
assert(not ok and confirmation and message:find('Ctrl+S', 1, true))
local f = assert(io.open(path, 'rb'))
assert(f:read('*a') == data); f:close()
ok, message, confirmation = Recipe.save(path, data .. '\n', true)
assert(ok and message == 'Saved' and not confirmation)
local previous = assert(io.open(path .. '.bak1', 'rb'))
assert(previous:read('*a') == data); previous:close()
local parsed = assert(Recipe.load(path, 'Data', 'PANEL04V', true, 28))
assert(#parsed.items == 2)
os.remove(path)
os.remove(path .. '.bak1')
-- Valid bulk selections with large but bounded offsets can exceed 32 KiB.
-- Saving must never produce a recipe the same loader immediately rejects.
local large_rows = {}
for id = 0, 2047 do
  large_rows[#large_rows + 1] = {id = id, dx = -4096, dy = 4096, repeat_count = 99}
end
local large_data = Recipe.serialize('Data', 'PANEL04V', true, 'layers', large_rows)
assert(#large_data > 32768 and #large_data < 128 * 1024)
local large_path = 'tests/sprite_viewer/tmp_large_codec_test.svr'
os.remove(large_path)
assert(Recipe.save(large_path, large_data, false))
local large_loaded = assert(Recipe.load(large_path, 'Data', 'PANEL04V', true, 2048))
assert(#large_loaded.items == 2048 and large_loaded.items[2048].dx == -4096)
local blocked, reason = Recipe.save(large_path, string.rep('X', 128 * 1024 + 1), true)
assert(not blocked and reason:find('128 KiB', 1, true))
local preserved = assert(io.open(large_path, 'rb'))
assert(preserved:read('*a') == large_data, 'oversized save must preserve existing recipe')
preserved:close()
os.remove(large_path)
-- A pre-existing oversized file must be read only to the bounded comparison
-- limit, while a replacement still backs up the complete original bytes.
local old_large = string.rep('O', 256 * 1024)
local previous_path = 'tests/sprite_viewer/tmp_existing_large.svr'
os.remove(previous_path)
os.remove(previous_path .. '.bak1')
local old_fh = assert(io.open(previous_path, 'wb'))
assert(old_fh:write(old_large))
old_fh:close()
local _, _, needs_confirm = Recipe.save(previous_path, data, false)
assert(needs_confirm, 'existing oversized recipe still requires confirmation')
assert(Recipe.save(previous_path, data, true))
local full_backup = assert(io.open(previous_path .. '.bak1', 'rb'))
assert(full_backup:read('*a') == old_large, 'bounded comparison must not truncate backup')
full_backup:close()
os.remove(previous_path)
os.remove(previous_path .. '.bak1')
print('PASS: standalone recipe codec/IO; bounded read/write, backup and large round-trip')
