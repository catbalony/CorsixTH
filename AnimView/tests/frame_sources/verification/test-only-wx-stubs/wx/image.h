#pragma once
#include <vector>
#include <cstdint>
class wxImage {
  int w_,h_;
  std::vector<unsigned char> rgb_, alpha_;
public:
  wxImage(int w,int h,bool /*clear*/=true):w_(w),h_(h),rgb_(w*h*3,0),alpha_(w*h,0){}
  unsigned char* GetData() {return rgb_.data();}
  int GetWidth() const{return w_;}
  int GetHeight() const{return h_;}
  bool HasAlpha() const{return !alpha_.empty();}
  void SetAlpha(int x,int y,unsigned char value){if(x>=0&&y>=0&&x<w_&&y<h_)alpha_[y*w_+x]=value;}
  const std::vector<unsigned char>& RGB()const{return rgb_;}
  const std::vector<unsigned char>& Alpha()const{return alpha_;}
};
