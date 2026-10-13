// SPDX-License-Identifier: MIT
#pragma once
#include <utility>
#include <M5GFX.h>
#include "RobotHomeCharacters.h"
namespace robot_home {
// Both firmware and native preview use this canvas, so previews exercise the
// same RGB565 cache, rotation and scale operations as the device.
template<class Base>
class PortraitCanvas : public Base {
 public:
  template<class...Args> explicit PortraitCanvas(Args&&...args):Base(std::forward<Args>(args)...) {}
  void preparePortraits() {
    PortraitImage images[4];
    for(int i=0;i<4;++i)images[i]=character_art::assetFor(static_cast<Character>(i));
    cache_.prepare(images,4);
  }
  void clearPortraits() {cache_.clear();}
  void drawPortrait(const std::uint8_t* bytes,std::uint32_t size,float cx,float cy,float scale,float angle) {
    std::int32_t x,y,w,h;
    this->getClipRect(&x,&y,&w,&h);
    const int left=std::max(64,static_cast<int>(x)), top=std::max(64,static_cast<int>(y));
    const int right=std::min(403,static_cast<int>(x+w)), bottom=std::min(399,static_cast<int>(y+h));
    this->setClipRect(left,top,std::max(0,right-left),std::max(0,bottom-top));
    if(!cache_.draw(*this,{bytes,size},cx,cy,scale,angle)) {
      // Extreme allocation/decode failure: a small neutral face still answers
      // input. Never retry JPEG decode or allocate on every animation frame.
      this->fillSmoothRoundRect(cx-40,cy-50,80,100,16,0x3186);
      this->drawLine(cx-24,cy-10,cx-8,cy-10,0xBFFF);
      this->drawLine(cx+8,cy-10,cx+24,cy-10,0xBFFF);
    }
    this->setClipRect(x,y,w,h);
  }
 private:
  PortraitCache<lgfx::LGFX_Sprite> cache_;
};
}
