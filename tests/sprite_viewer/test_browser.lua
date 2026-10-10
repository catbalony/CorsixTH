local Browser = require('sprite_viewer_browser')
local names = { {'Data','PANEL02V'}, {'Data','PANEL04V'}, {'QData','PREF01V'} }
local label = function(v) return table.concat(v, '/') end
local found = Browser.filter(names, 'Panel', label)
assert(#found == 2 and found[1].index == 1 and found[2].index == 2)
assert(#Browser.filter(names, 'notpresent', label) == 0)
assert(#Browser.filter(names, '', label) == 3)
local palettes = {'MPalette.dat', 'Pref01V.pal', 'Panel02V.pal'}
assert(Browser.closest_palette('PREF01V', palettes) == 2)
assert(Browser.closest_palette('PANEL02V', palettes) == 3)
assert(Browser.closest_palette('GOBBLE', palettes) == nil)
print('PASS: browser filtering, case folding, stable source indices and closest palette')
