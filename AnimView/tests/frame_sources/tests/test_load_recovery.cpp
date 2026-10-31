#include "th.h"
#include <cassert>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

namespace fs = std::filesystem;
static wxString wxpath(const fs::path& p) { return wxString(p.string()); }
static bool loadAll(THAnimations& a, const fs::path& d) {
  const fs::path data=d/"DATA", qdata=d/"QDATA";
  return a.loadAnimationFile(wxpath(data/"VSTART-1.ANI")) &&
         a.loadFrameFile(wxpath(data/"VFRA-1.ANI")) &&
         a.loadListFile(wxpath(data/"VLIST-1.ANI")) &&
         a.loadElementFile(wxpath(data/"VELE-1.ANI")) &&
         a.loadTableFile(wxpath(data/"VSPR-0.TAB")) &&
         a.loadSpriteFile(wxpath(data/"VSPR-0.DAT")) &&
         a.loadPaletteFile(wxpath(data/"MPALETTE.DAT")) &&
         a.loadGhostFile(wxpath(qdata/"GHOST1.DAT"),1) &&
         a.loadGhostFile(wxpath(qdata/"GHOST2.DAT"),2) &&
         a.loadGhostFile(wxpath(qdata/"GHOST66.DAT"),3);
}
int main(int argc, char** argv) {
  assert(argc==3);
  const fs::path fixture=argv[1], temp=argv[2];
  fs::create_directories(temp);
  THAnimations original;
  assert(loadAll(original,fixture));
  assert(original.getAnimationCount()==1 && original.getFrameCount(0)==3);
  assert(original.getSpriteCount()==2);
  Bitmap* first=original.getSpriteBitmap(0);
  assert(first && first->pixel(0,0)==255 && first->pixel(16,16)==2);
  // Finding #1: a failed replacement TAB must not empty decoded bitmap cache.
  assert(!original.loadTableFile(wxpath(temp/"not-found.TAB")));
  assert(original.getSpriteCount()==2);
  first=original.getSpriteBitmap(0);
  assert(first && first->pixel(16,16)==2);
  assert(original.getSpriteBitmap(1));
  // A malformed replacement TAB is rejected without losing the prior record set.
  { std::ofstream f(temp/"incomplete.TAB",std::ios::binary); f.put('\x01'); }
  assert(!original.loadTableFile(wxpath(temp/"incomplete.TAB")));
  assert(original.getSpriteBitmap(0)->pixel(16,16)==2);
  // Finding #2: a successful DAT replacement must invalidate cached pixels.
  const fs::path fresh=temp/"changed.DAT";
  auto dat=fixture/"DATA"/"VSPR-0.DAT";
  fs::copy_file(dat,fresh,fs::copy_options::overwrite_existing);
  { std::fstream f(fresh,std::ios::binary|std::ios::in|std::ios::out);
    assert(f); f.seekp(0); // Synthetic stream changes first sprite's colour run.
    // Keep decode controls valid and change a literal colour used by the glyph.
    // Ensure a byte changed at a deterministic interior location.
    // The pixel at 16,16 must change, confirmed below using a fresh model.
    std::vector<unsigned char> v((std::istreambuf_iterator<char>(f)),{});
    assert(v.size()>6);
    // Change all appearances of palette index 2 (never stream control in this synthetic fixture).
    bool changed=false;
    for (size_t i=1;i<v.size();++i) if(v[i]==2) { v[i]=14; changed=true; }
    assert(changed);
    f.clear(); f.seekp(0);
    f.write(reinterpret_cast<const char*>(v.data()),v.size());
  }
  THAnimations independent;
  assert(independent.loadTableFile(wxpath(fixture/"DATA"/"VSPR-0.TAB")));
  assert(independent.loadSpriteFile(wxpath(fresh)));
  auto* expected=independent.getSpriteBitmap(0);
  assert(expected && expected->pixel(16,16)!=2);
  assert(original.loadSpriteFile(wxpath(fresh)));
  auto* after=original.getSpriteBitmap(0);
  assert(after && after->pixel(16,16)==expected->pixel(16,16));
  assert(after->pixel(16,16)!=2);
  // Failed DAT replacements must keep cached results and data unchanged.
  assert(!original.loadSpriteFile(wxpath(temp/"not-found.DAT")));
  assert(original.getSpriteBitmap(0)->pixel(16,16)==expected->pixel(16,16));
  // A valid TAB replacement rebuilds its cache against currently loaded DAT.
  assert(original.loadTableFile(wxpath(fixture/"DATA"/"VSPR-0.TAB")));
  assert(original.getSpriteBitmap(0)->pixel(16,16)==expected->pixel(16,16));
  // Finding #3: use a temporary model for multi-file loads. A broken candidate
  // never gets committed, leaving previous frames, palette and cached pixels.
  THAnimations candidate;
  assert(candidate.loadAnimationFile(wxpath(fixture/"DATA"/"VSTART-1.ANI")));
  assert(!candidate.loadFrameFile(wxpath(temp/"VFRA-1.ANI")));
  assert(original.getFrameCount(0)==3);
  assert(original.getSpriteBitmap(0)->pixel(16,16)==expected->pixel(16,16));
  assert(original.hasValidPalette());
  // Successful candidate commit is a swap of fully validated records/caches.
  THAnimations complete;
  assert(loadAll(complete,fixture));
  assert(complete.markDuplicates()==1);
  original.swapLoadedData(complete);
  assert(original.getFrameCount(0)==3 && original.getSpriteCount()==2);
  assert(original.getSpriteBitmap(0)->pixel(16,16)==2);
  std::vector<THFrameSource> out;
  assert(original.getFrameSources(0,0,nullptr,out) && out.size()==1 && out[0].sprite_id==0);
  std::cout << "PASS: failed TAB/DAT loads preserve state; successful DAT clears cache; complete animation commit is atomic\n";
}
