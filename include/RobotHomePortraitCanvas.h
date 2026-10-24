// SPDX-License-Identifier: MIT
#pragma once
#include <utility>
#include <M5GFX.h>
#include "RobotHomeCharacters.h"
namespace robot_home {
// Both firmware and native preview use this canvas, so previews exercise the
// same RGB565 cache, rotation and scale operations as the device.
template<class Base, class Sprite = lgfx::LGFX_Sprite>
class PortraitCanvas : public Base {
 public:
  template<class...Args> explicit PortraitCanvas(Args&&...args):Base(std::forward<Args>(args)...) {}
  void preparePortraits(Character current = Character::Bumblebee) {
    PortraitImage images[kCharacterCount];
    for(int i=0;i<kCharacterCount;++i)images[i]=character_art::assetFor(static_cast<Character>(i));
    cache_.prepare(images,kCharacterCount);
    if(actionsPrepared_&&current==current_)return;
    actions_.clear(); // evict the old role before allocating the new role
    PortraitImage actions[2];
    std::size_t count=0;
    for(const auto& action:character_art::kActions)
      if(action.character==current&&count<2)actions[count++]=action.image;
    actions_.prepare(actions,count,false);
    current_=current;actionsPrepared_=true; // remember failures too; no frame retries
  }
  // Agent desktops keep the idle bank warm for the next Home frame. Only
  // role-specific response images are disposable during an awake page cycle.
  void clearActions() {
    actions_.clear();
    current_=Character::Bumblebee;actionsPrepared_=false;
  }
  void clearPortraits() {
    clearActions();cache_.clear();
  }
  void drawPortrait(const std::uint8_t* bytes,std::uint32_t size,float cx,float cy,float scale,float angle,bool notificationBadgeVisible=false) {
    std::int32_t x,y,w,h;
    this->getClipRect(&x,&y,&w,&h);
    constexpr float fit=288.f/339.f;
    int clipTop=64,clipRight=403,clipBottom=399;
    if(notificationBadgeVisible) {
      // Preserve the accepted portrait layout and clipping independently of
      // notification badge placement. Moving the badge must not move the role.
      cx=64+(cx-64)*fit;cy=232+(cy-232)*fit;scale*=fit;
      clipTop=static_cast<int>(std::ceil(232+(64-232)*fit));
      clipBottom=static_cast<int>(std::floor(232+(399-232)*fit));
      clipRight=352;
    }
    const int left=std::max(64,static_cast<int>(x)), top=std::max(clipTop,static_cast<int>(y));
    const int right=std::min(clipRight,static_cast<int>(x+w)), bottom=std::min(clipBottom,static_cast<int>(y+h));
    this->setClipRect(left,top,std::max(0,right-left),std::max(0,bottom-top));
    const PortraitImage image{bytes,size};
    const auto idle=character_art::idleForAsset(image);
    const bool drawn=idle.bytes==bytes
      ?cache_.draw(*this,image,cx,cy,scale,angle)
      :(actions_.draw(*this,image,cx,cy,scale,angle)||cache_.draw(*this,idle,cx,cy,scale,angle));
    if(!drawn) {
      // Extreme allocation/decode failure: a small neutral face still answers
      // input. Never retry JPEG decode or allocate on every animation frame.
      this->fillSmoothRoundRect(cx-40,cy-50,80,100,16,0x3186);
      this->drawLine(cx-24,cy-10,cx-8,cy-10,0xBFFF);
      this->drawLine(cx+8,cy-10,cx+24,cy-10,0xBFFF);
    }
    this->setClipRect(x,y,w,h);
  }
 private:
  PortraitCache<Sprite,kCharacterCount> cache_;
  PortraitCache<Sprite,2> actions_;
  Character current_=Character::Bumblebee;
  bool actionsPrepared_=false;
};
}
