#include "th.h"
#include <cassert>
#include <iostream>
#include <vector>
#include <string>

bool load(THAnimations& a, const std::string& d) {
  return a.loadAnimationFile(wxString(d+"/VSTART-1.ANI")) &&
         a.loadFrameFile(wxString(d+"/VFRA-1.ANI")) &&
         a.loadListFile(wxString(d+"/VLIST-1.ANI")) &&
         a.loadElementFile(wxString(d+"/VELE-1.ANI")) &&
         a.loadTableFile(wxString(d+"/VSPR-0.TAB")) &&
         a.loadSpriteFile(wxString(d+"/VSPR-0.DAT")) &&
         a.loadPaletteFile(wxString(d+"/MPALETTE.DAT"));
}
int main(int argc, char** argv) {
  assert(argc == 4);
  const std::string synthetic=argv[1], malformed=argv[2], transparent=argv[3];
  THAnimations a;
  assert(load(a,synthetic));
  assert(a.getFrameCount(0)==3);
  assert(a.hasValidPalette());
  std::vector<THFrameSource> refs;
  THLayerMask m;
  assert(a.getFrameSources(0,0,&m,refs));
  assert(refs.size()==1);
  assert(refs[0].element_id==0 && refs[0].sprite_id==0);
  assert(refs[0].x==10 && refs[0].y==10);
  assert(refs[0].width==2 && refs[0].height==2);
  assert(refs[0].layer==0 && refs[0].layer_id==0);
  assert(!refs[0].enabled_by_mask);
  m.set(0,0);
  assert(a.getFrameSources(0,0,&m,refs) && refs[0].enabled_by_mask);
  assert(a.getFrameSources(0,1,&m,refs) && refs.size()==1 && refs[0].sprite_id==1);
  assert(a.getFrameSources(0,2,nullptr,refs) && refs.size()==1 && refs[0].sprite_id==0);
  auto keep=refs;
  assert(!a.getFrameSources(100,0,&m,refs));
  assert(!a.getFrameSources(0,3,&m,refs));
  assert(!a.getFrameSources(0,1024,&m,refs));
  assert(refs.size()==keep.size() && refs[0].sprite_id==keep[0].sprite_id);
  // Original VSPR bytes: image 2x2 has four original palette values.
  auto* pix=a.getSpriteBitmap(0);
  assert(pix && pix->getWidth()==2 && pix->getHeight()==2);
  assert(pix->pixel(0,0)==1 && pix->pixel(1,0)==2);
  assert(a.getPalette()[1].r==4 && a.getPalette()[2].r==8);
  // The *same* RGB generation path used by the GUI is tested without wx.
  std::vector<uint8_t> preview;
  int zoom = -1;
  assert(a.renderSourcePreview(0, 256, preview, zoom));
  assert(zoom == 8 && preview.size() == 256u * 256u * 3u);
  // A 2x2 sprite is centered and each indexed pixel is 8x8 canvas pixels.
  const auto pixel = [&](int x, int y, int channel) {
    return preview[3 * (y * 256 + x) + channel];
  };
  assert(pixel(120,120,0) == a.getPalette()[1].r);
  assert(pixel(128,120,0) == a.getPalette()[2].r);
  // A gap outside the sprite is neutral checkerboard, not black.
  assert(pixel(0,0,0) == 245);
  assert(pixel(8,0,0) == 218);
  const auto previous = preview;
  const int previous_zoom = zoom;
  assert(!a.renderSourcePreview(99999,256,preview,zoom));
  assert(!a.renderSourcePreview(0,8192,preview,zoom));
  assert(preview == previous && zoom == previous_zoom);
  // Transparent index 255 reveals the checkerboard at original-pixel zoom.
  THAnimations alpha;
  assert(load(alpha,transparent));
  const Bitmap* transparent_bitmap = alpha.getSpriteBitmap(0);
  assert(transparent_bitmap && transparent_bitmap->pixel(1,0)==255);
  std::vector<uint8_t> alpha_preview;
  int alpha_zoom=0;
  assert(alpha.renderSourcePreview(0,256,alpha_preview,alpha_zoom));
  assert(alpha_zoom==8);
  assert(alpha_preview[3 * (120 * 256 + 128)] == 218);
  assert(alpha_preview[3 * (120 * 256 + 120)] == alpha.getPalette()[1].r);
  // A missing palette must never become an apparently valid preview.
  THAnimations no_palette;
  assert(no_palette.loadTableFile(wxString(transparent+"/VSPR-0.TAB")));
  assert(no_palette.loadSpriteFile(wxString(transparent+"/VSPR-0.DAT")));
  std::vector<uint8_t> keep_pixels{42, 43, 44};
  int keep_zoom=3;
  assert(!no_palette.renderSourcePreview(0,256,keep_pixels,keep_zoom));
  assert(keep_pixels==std::vector<uint8_t>({42,43,44}) && keep_zoom==3);
  // Reject an incomplete palette without losing the last valid one.
  const auto old_colour=a.getPalette()[1].r;
  assert(!a.loadPaletteFile(wxString(synthetic+"/VSPR-0.TAB")));
  assert(a.getPalette()[1].r == old_colour);
  THAnimations b;
  assert(load(b,malformed));
  std::vector<THFrameSource> sentinel=refs;
  assert(!b.getFrameSources(0,0,nullptr,sentinel));
  assert(sentinel.size()==refs.size() && sentinel[0].sprite_id==refs[0].sprite_id);
  assert(b.getFrameSources(0,1,nullptr,sentinel));
  std::cout<<"PASS: frame source identity, original sprite pixels, masks, frame order,"
           <<" malformed lists, state preservation\n";
}
