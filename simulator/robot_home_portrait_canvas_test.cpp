// Exercise the real Canvas and both real caches; only RGB565 Sprite IO is injected.
#include <cassert>
#include <algorithm>
#include <cstdio>
#include <cmath>
#include "RobotHomePortraitCanvas.h"
struct Surface {
  int x=0,y=0,w=466,h=466,neutral=0;
  void getClipRect(int* a,int* b,int* c,int* d) {*a=x;*b=y;*c=w;*d=h;}
  void setClipRect(int a,int b,int c,int d) {x=a;y=b;w=c;h=d;}
  void fillSmoothRoundRect(float,float,int,int,int,int) {++neutral;}
  void drawLine(float,float,float,float,int) {}
};
struct Sprite {
  inline static int live=0,peak=0,decodes=0,allocations=0,budget=19;
  inline static const std::uint8_t* badImage=nullptr;
  inline static const std::uint8_t* drawn=nullptr;
  inline static float angle=0,scale=0,centerY=0;
  bool allocated=false;
  const std::uint8_t* pixels=nullptr;
  void setPsram(bool) {}
  void setColorDepth(int) {}
  void setPivot(int,int) {}
  void* createSprite(int w,int h) {
    assert(w==300&&h==300&&!allocated);
    if(live>=budget)return nullptr;
    allocated=true;++allocations;peak=std::max(peak,++live);return this;
  }
  void deleteSprite() {assert(allocated);allocated=false;--live;pixels=nullptr;}
  void fillScreen(int) {pixels=nullptr;}
  bool drawJpg(const std::uint8_t* bytes,std::uint32_t,int,int) {
    ++decodes;if(bytes==badImage)return false;pixels=bytes;return true;
  }
  template<class Canvas> void pushRotateZoom(Canvas*,float,float cy,float a,float s,float,int) {
    assert(allocated&&pixels);drawn=pixels;angle=a;scale=s;centerY=cy;
  }
};
using Canvas=robot_home::PortraitCanvas<Surface,Sprite>;
using namespace robot_home;
void reset(int budget=19) {
  assert(Sprite::live==0);
  Sprite::peak=Sprite::decodes=Sprite::allocations=0;Sprite::budget=budget;
  Sprite::badImage=Sprite::drawn=nullptr;
}
void draw(Canvas& canvas, PortraitImage image, Motion motion={}) {
  Sprite::drawn=nullptr;
  canvas.drawPortrait(image.bytes,image.size,233,232+motion.offsetY,1.18f*motion.scale,motion.angle);
  assert(canvas.x==0&&canvas.y==0&&canvas.w==466&&canvas.h==466);
}
void correctFallback(Canvas& canvas,Character role) {
  const auto motion=motionFor(role,Mood::Skill,300);
  assert(motion.pose==1&&(motion.angle!=0||motion.offsetY!=0||motion.scale!=1));
  draw(canvas,character_art::actionFor(role,1),motion);
  assert(Sprite::drawn==character_art::assetFor(role).bytes);
  assert(Sprite::angle==motion.angle&&Sprite::scale==1.18f*motion.scale&&Sprite::centerY==232+motion.offsetY);
}
int main() {
  {
    Canvas canvas;
    canvas.preparePortraits();
    // Default portrait has no action assets: seventeen idles, no unrelated actions.
    assert(Sprite::live==17&&Sprite::decodes==17);
    for(int i=0;i<17;++i) {
      const auto idle=character_art::assetFor(static_cast<Character>(i));
      draw(canvas,idle);assert(Sprite::drawn==idle.bytes);
    }
    assert(Sprite::decodes==17);
    canvas.preparePortraits(Character::BumblebeeFullbody);
    assert(Sprite::live==19&&Sprite::decodes==19);
    const auto oldAction=character_art::actionFor(Character::BumblebeeFullbody,2);
    draw(canvas,oldAction);assert(Sprite::drawn==oldAction.bytes);
    const int decoded=Sprite::decodes,allocated=Sprite::allocations;
    for(int i=0;i<100;++i) {
      canvas.preparePortraits(Character::BumblebeeFullbody);
      draw(canvas,character_art::actionFor(Character::BumblebeeFullbody,1+i%2));
    }
    assert(Sprite::decodes==decoded&&Sprite::allocations==allocated);
    canvas.preparePortraits(Character::Megatron);
    assert(Sprite::live==18&&Sprite::decodes==20);
    draw(canvas,character_art::actionFor(Character::Megatron,1));
    assert(Sprite::drawn==character_art::actionFor(Character::Megatron,1).bytes);
    draw(canvas,oldAction); // old action pixels were evicted; its idle remains correct
    assert(Sprite::drawn==character_art::assetFor(Character::BumblebeeFullbody).bytes);
    for(int i=0;i<17;++i) {
      const auto role=static_cast<Character>(i);
      canvas.preparePortraits(role);
      const int before=Sprite::decodes;
      for(int frame=0;frame<60;++frame) {
        canvas.preparePortraits(role);
        const auto image=character_art::actionFor(role,motionFor(role,Mood::Skill,frame*10).pose);
        draw(canvas,image);assert(Sprite::drawn==image.bytes);
      }
      assert(Sprite::decodes==before&&Sprite::live<=19);
    }
    assert(Sprite::peak==19);
    canvas.clearPortraits();assert(Sprite::live==0);
    const int before=Sprite::decodes;
    canvas.preparePortraits(Character::Astrotrain);
    assert(Sprite::live==18&&Sprite::decodes==before+18);
    draw(canvas,character_art::actionFor(Character::Astrotrain,1));
    assert(Sprite::drawn==character_art::actionFor(Character::Astrotrain,1).bytes);
  }
  // Failure of either first or second action allocation releases the partial
  // bank, preserves all idles and never retries allocation/decode each frame.
  for(int budget:{17,18}) {
    reset(budget);
    Canvas canvas;
    canvas.preparePortraits(Character::BumblebeeFullbody);
    assert(Sprite::live==17);
    const int decoded=Sprite::decodes,allocated=Sprite::allocations;
    for(int i=0;i<60;++i) {
      canvas.preparePortraits(Character::BumblebeeFullbody);
      draw(canvas,character_art::actionFor(Character::BumblebeeFullbody,1+i%2));
      assert(Sprite::drawn==character_art::assetFor(Character::BumblebeeFullbody).bytes);
    }
    assert(Sprite::decodes==decoded&&Sprite::allocations==allocated);
    Sprite::budget=17;canvas.preparePortraits(Character::Megatron);
    const int failedDecodes=Sprite::decodes,failedAllocations=Sprite::allocations;
    for(int i=0;i<60;++i) {canvas.preparePortraits(Character::Megatron);correctFallback(canvas,Character::Megatron);}
    assert(Sprite::decodes==failedDecodes&&Sprite::allocations==failedAllocations);
  }
  reset();
  {
    Canvas canvas;
    Sprite::badImage=character_art::actionFor(Character::Skywarp,1).bytes;
    canvas.preparePortraits(Character::Skywarp);
    const int decoded=Sprite::decodes;
    for(int i=0;i<60;++i) {canvas.preparePortraits(Character::Skywarp);correctFallback(canvas,Character::Skywarp);}
    assert(Sprite::decodes==decoded);
    canvas.clearPortraits();assert(Sprite::live==0);
    Sprite::badImage=nullptr;canvas.preparePortraits(Character::Skywarp);
    draw(canvas,character_art::actionFor(Character::Skywarp,1));
    assert(Sprite::drawn==character_art::actionFor(Character::Skywarp,1).bytes);
  }
  reset(1);
  {
    Canvas canvas;canvas.preparePortraits(Character::Astrotrain);
    assert(Sprite::live==1);correctFallback(canvas,Character::Astrotrain);
    const int decoded=Sprite::decodes;
    for(int i=0;i<60;++i)correctFallback(canvas,Character::Astrotrain);
    assert(Sprite::decodes==decoded);
    canvas.preparePortraits(Character::Megatron);correctFallback(canvas,Character::Megatron);
  }
  reset(0);
  {
    Canvas canvas;canvas.preparePortraits(Character::Megatron);
    for(int i=0;i<60;++i)draw(canvas,character_art::actionFor(Character::Megatron,1));
    assert(canvas.neutral==60&&Sprite::decodes==0&&Sprite::allocations==0);
  }
  assert(Sprite::live==0);
  std::puts("PASS real PortraitCanvas: 17 idles + 2 current actions, peak19, reuse, switch, clear, allocation/decode fallback");
}
