#include <cassert>
#include <cstdint>
#include "RobotHomePortraitCache.h"
struct Canvas {};
struct Sprite {
  inline static int allocations=0, frees=0, decodes=0, draws=0, budget=4;
  inline static bool decodeOk=true;
  bool allocated=false;
  void setPsram(bool) {}
  void setColorDepth(int) {}
  void setPivot(int,int) {}
  void* createSprite(int w,int h) {assert(w==300&&h==300);if(allocations-frees>=budget)return nullptr;allocated=true;++allocations;return this;}
  void deleteSprite() {if(allocated){++frees;allocated=false;}}
  void fillScreen(int) {}
  bool drawJpg(const std::uint8_t*,std::uint32_t,int,int) {++decodes;return decodeOk;}
  void pushRotateZoom(Canvas*,float,float,float,float,float,int) {++draws;}
};
int main() {
  const std::uint8_t a[]={1},b[]={2},c[]={3},d[]={4};
  const robot_home::PortraitImage images[]={{a,1},{b,1},{c,1},{d,1}};
  Canvas canvas;
  {
    robot_home::PortraitCache<Sprite> cache;
    cache.prepare(images,4);
    assert(Sprite::decodes==4);
    for(int i=0;i<50;++i) assert(cache.draw(canvas,images[i%4],233,232,1.18f,0));
    assert(Sprite::decodes==4&&Sprite::draws==50); // actual decode avoided
    cache.clear();assert(Sprite::frees==4);
  }
  Sprite::budget=1;
  {
    robot_home::PortraitCache<Sprite> cache;
    cache.prepare(images,4);
    // Low memory: at most one current-portrait buffer, reused across selection.
    assert(cache.draw(canvas,images[2],233,232,1,0));
    const int decoded=Sprite::decodes;
    for(int i=0;i<50;++i)assert(cache.draw(canvas,images[2],233,232,1,0));
    assert(Sprite::decodes==decoded);
    assert(cache.draw(canvas,images[3],233,232,1,0));
    assert(Sprite::decodes==decoded+1);
    Sprite::decodeOk=false;
    assert(!cache.draw(canvas,images[1],233,232,1,0));
    Sprite::decodeOk=true;
    assert(cache.draw(canvas,images[3],233,232,1,0)); // restore overwritten valid portrait
  }
  assert(Sprite::allocations==Sprite::frees);
  Sprite::budget=0;
  {
    robot_home::PortraitCache<Sprite> cache;
    cache.prepare(images,4);
    assert(!cache.draw(canvas,images[0],233,232,1,0));
    assert(!cache.draw(canvas,images[0],233,232,1,0));
  }
  Sprite::budget=4;Sprite::decodeOk=false;
  {
    robot_home::PortraitCache<Sprite> cache;
    cache.prepare(images,4);
    assert(!cache.draw(canvas,images[0],233,232,1,0));
    const int decoded=Sprite::decodes;
    for(int i=0;i<50;++i)assert(!cache.draw(canvas,images[0],233,232,1,0));
    assert(Sprite::decodes==decoded); // bad asset never retried every frame
  }
  assert(Sprite::allocations==Sprite::frees);
}
