#include <cassert>
#include <cstdint>
#include <initializer_list>
#include "RobotHomePortraitCache.h"
struct Canvas {};
struct Sprite {
  inline static int allocations=0, frees=0, decodes=0, draws=0, budget=7;
  inline static const std::uint8_t* badImage=nullptr;
  bool allocated=false;
  void setPsram(bool) {}
  void setColorDepth(int) {}
  void setPivot(int,int) {}
  void* createSprite(int w,int h) {assert(w==300&&h==300);if(allocations-frees>=budget)return nullptr;allocated=true;++allocations;return this;}
  void deleteSprite() {assert(allocated);++frees;allocated=false;}
  void fillScreen(int) {}
  bool drawJpg(const std::uint8_t* bytes,std::uint32_t,int,int) {++decodes;return bytes!=badImage;}
  void pushRotateZoom(Canvas*,float,float,float,float,float,int) {assert(allocated);++draws;}
};
void reset(int budget) {
  assert(Sprite::allocations==Sprite::frees);
  Sprite::allocations=Sprite::frees=Sprite::decodes=Sprite::draws=0;
  Sprite::budget=budget;Sprite::badImage=nullptr;
}
int main() {
  const std::uint8_t bytes[]={1,2,3,4,5,6,7};
  const robot_home::PortraitImage images[]={{bytes,1},{bytes+1,1},{bytes+2,1},{bytes+3,1},{bytes+4,1},{bytes+5,1},{bytes+6,1}};
  Canvas canvas;
  {
    robot_home::PortraitCache<Sprite> cache;
    cache.prepare(images,7);
    assert(Sprite::decodes==7);
    cache.prepare(images,7);assert(Sprite::decodes==7);
    for(int i=0;i<70;++i) assert(cache.draw(canvas,images[i%7],233,232,1.18f,0));
    assert(Sprite::decodes==7&&Sprite::draws==70);
    const std::uint8_t unknown[]={8};
    assert(!cache.draw(canvas,{unknown,1},233,232,1,0));
    cache.clear();assert(Sprite::frees==7);
    cache.prepare(images,7);assert(Sprite::decodes==14);
  }
  assert(Sprite::frees==14);
  for(int budget:{4,1}) {
    reset(budget);
    {
      robot_home::PortraitCache<Sprite> cache;
      cache.prepare(images,7);
      assert(Sprite::allocations-Sprite::frees==1);
      for(int i=0;i<7;++i) {
        assert(cache.draw(canvas,images[i],233,232,1,0));
        const int decoded=Sprite::decodes;
        for(int repeat=0;repeat<50;++repeat)assert(cache.draw(canvas,images[i],233,232,1,0));
        assert(Sprite::decodes==decoded);
      }
      Sprite::badImage=bytes+5;
      assert(!cache.draw(canvas,images[5],233,232,1,0));
      const int decoded=Sprite::decodes;
      for(int i=0;i<50;++i) assert(!cache.draw(canvas,images[5],233,232,1,0));
      assert(Sprite::decodes==decoded);
      assert(cache.draw(canvas,images[6],233,232,1,0));
      assert(Sprite::decodes==decoded+1); // restore overwritten reused pixels
    }
  }
  reset(0);
  {
    robot_home::PortraitCache<Sprite> cache;
    cache.prepare(images,7);
    for(const auto& image:images)for(int i=0;i<10;++i)assert(!cache.draw(canvas,image,233,232,1,0));
    assert(Sprite::decodes==0&&Sprite::allocations==0);
  }
  reset(7);Sprite::badImage=bytes+6;
  {
    robot_home::PortraitCache<Sprite> cache;
    cache.prepare(images,7);assert(Sprite::decodes==7);
    for(int i=0;i<50;++i)assert(!cache.draw(canvas,images[6],233,232,1,0));
    for(int i=0;i<6;++i)assert(cache.draw(canvas,images[i],233,232,1,0));
    assert(Sprite::decodes==7);
  }
  assert(Sprite::allocations==Sprite::frees&&Sprite::frees==7);
}
