// Optional PRIVATE test. Reads original Theme Hospital data from a user-supplied
// directory. This source code and numeric results may be shared; game bytes may not.
#include "th.h"
#include <cassert>
#include <iostream>
#include <string>
#include <vector>
int main(int argc,char**argv){
 if(argc!=2){std::cerr<<"Usage: test_real_game_optional PATH_TO_DATA\n";return 2;}
 std::string d=argv[1]; THAnimations a;
 auto f=[&](const char* s){return wxString(d+"/"+s);};
 if(!(a.loadAnimationFile(f("VSTART-1.ANI"))&&a.loadFrameFile(f("VFRA-1.ANI"))&&
      a.loadListFile(f("VLIST-1.ANI"))&&a.loadElementFile(f("VELE-1.ANI"))&&
      a.loadTableFile(f("VSPR-0.TAB"))&&a.loadSpriteFile(f("VSPR-0.DAT"))&&
      a.loadPaletteFile(f("MPALETTE.DAT")))) {std::cerr<<"private data load failed\n";return 3;}
 size_t occ=0,refs=0,broken=0;
 std::vector<THFrameSource> frame;
 for(size_t anim=0;anim<a.getAnimationCount();++anim){
   for(size_t ordinal=0;ordinal<a.getFrameCount(anim);++ordinal){
     ++occ;
     if(!a.getFrameSources(anim,ordinal,nullptr,frame)){++broken;continue;}
     refs+=frame.size();
   }
 }
 size_t count=a.getAnimationCount(),spr=a.getSpriteCount();
 std::cout<<"animations="<<count<<" sprites="<<spr<<" frame_occurrences="<<occ<<" sources="<<refs<<" invalid="<<broken<<"\n";
 if(broken||count!=5186||spr!=4397) return 4;
 auto* pix=a.getSpriteBitmap(2504); if(!pix||!pix->IsOk())return 5;
 const int w=pix->getWidth(),h=pix->getHeight();
 if(a.loadTableFile(f("missing.TAB")))return 6;
 if(a.getSpriteCount()!=spr||!a.getSpriteBitmap(2504)||a.getSpriteBitmap(2504)->getWidth()!=w||a.getSpriteBitmap(2504)->getHeight()!=h)return 7;
 std::cout<<"PASS: real data complete; rejected TAB preserves cached sprite #2504\n";
}
