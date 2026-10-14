#include <cassert>
#include <cstdint>
#include <initializer_list>
#include "RobotHomePortraitCache.h"
struct Canvas {};
struct Sprite {
  inline static int allocations=0, frees=0, decodes=0, draws=0, budget=9;
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
  const std::uint8_t bytes[]={1,2,3,4,5,6,7,8,9};
  const robot_home::PortraitImage images[]={{bytes,1},{bytes+1,1},{bytes+2,1},{bytes+3,1},{bytes+4,1},{bytes+5,1},{bytes+6,1},{bytes+7,1},{bytes+8,1}};
  Canvas canvas;
  {
    robot_home::PortraitCache<Sprite> cache;
    cache.prepare(images,9);
    assert(Sprite::decodes==9);
    cache.prepare(images,9);assert(Sprite::decodes==9);
    for(int i=0;i<90;++i) assert(cache.draw(canvas,images[i%9],233,232,1.18f,0));
    assert(Sprite::decodes==9&&Sprite::draws==90);
    const std::uint8_t unknown[]={8};
    assert(!cache.draw(canvas,{unknown,1},233,232,1,0));
    cache.clear();assert(Sprite::frees==9);
    cache.prepare(images,9);assert(Sprite::decodes==18);
  }
  assert(Sprite::frees==18);
  for(int budget:{7,1}) {
    reset(budget);
    {
      robot_home::PortraitCache<Sprite> cache;
      cache.prepare(images,9);
      assert(Sprite::allocations-Sprite::frees==1);
      for(int i=0;i<9;++i) {
        assert(cache.draw(canvas,images[i],233,232,1,0));
        const int decoded=Sprite::decodes;
        for(int repeat=0;repeat<50;++repeat)assert(cache.draw(canvas,images[i],233,232,1,0));
        assert(Sprite::decodes==decoded);
      }
      assert(cache.draw(canvas,images[7],233,232,1,0));
      Sprite::badImage=bytes+8;
      assert(!cache.draw(canvas,images[8],233,232,1,0));
      const int decoded=Sprite::decodes;
      for(int i=0;i<50;++i) assert(!cache.draw(canvas,images[8],233,232,1,0));
      assert(Sprite::decodes==decoded);
      assert(cache.draw(canvas,images[7],233,232,1,0));
      assert(Sprite::decodes==decoded+1); // restore overwritten reused pixels
    }
  }
  reset(0);
  {
    robot_home::PortraitCache<Sprite> cache;
    cache.prepare(images,9);
    for(const auto& image:images)for(int i=0;i<10;++i)assert(!cache.draw(canvas,image,233,232,1,0));
    assert(Sprite::decodes==0&&Sprite::allocations==0);
  }
  reset(9);Sprite::badImage=bytes+8;
  {
    robot_home::PortraitCache<Sprite> cache;
    cache.prepare(images,9);assert(Sprite::decodes==9);
    for(int i=0;i<50;++i)assert(!cache.draw(canvas,images[8],233,232,1,0));
    for(int i=0;i<8;++i)assert(cache.draw(canvas,images[i],233,232,1,0));
    assert(Sprite::decodes==9);
  }
  assert(Sprite::allocations==Sprite::frees&&Sprite::frees==9);
  const std::uint8_t actionBytes[]={10,11,12,13,14,15,16,17,18,19};
  robot_home::PortraitImage poses[10];
  for(int i=0;i<10;++i)poses[i]={actionBytes+i,1};

  // Optional action bank must not evict the already prepared idle bank or
  // fall back to decoding each changing pose into one buffer on every frame.
  for(int budget=9;budget<19;++budget) {
    reset(budget);
    {
      robot_home::PortraitCache<Sprite> idle;
      robot_home::PortraitCache<Sprite,10> actions;
      idle.prepare(images,9);
      actions.prepare(poses,10,false);
      assert(Sprite::allocations-Sprite::frees==9);
      const int decoded=Sprite::decodes,allocated=Sprite::allocations;
      for(int i=0;i<100;++i) {
        assert(!actions.draw(canvas,poses[i%10],233,232,1,0));
        assert(idle.draw(canvas,images[i%9],233,232,1,0));
        actions.prepare(poses,10,false);
      }
      assert(Sprite::decodes==decoded&&Sprite::allocations==allocated);
    }
    assert(Sprite::allocations==Sprite::frees);
  }
  reset(19);
  {
    robot_home::PortraitCache<Sprite> idle;
    robot_home::PortraitCache<Sprite,10> actions;
    idle.prepare(images,9);
    actions.prepare(poses,10,false);
    assert(Sprite::allocations-Sprite::frees==19);
    assert(Sprite::decodes==19);
    for(int i=0;i<100;++i)assert(actions.draw(canvas,poses[i%10],233,232,1,0));
    assert(Sprite::decodes==19);
  }
  assert(Sprite::allocations==Sprite::frees);
  reset(19);Sprite::badImage=actionBytes+9;
  {
    robot_home::PortraitCache<Sprite> idle;
    robot_home::PortraitCache<Sprite,10> actions;
    idle.prepare(images,9);actions.prepare(poses,10,false);
    assert(Sprite::decodes==19);
    for(int i=0;i<100;++i) {
      assert(!actions.draw(canvas,poses[9],233,232,1,0));
      assert(idle.draw(canvas,images[8],233,232,1,0));
      assert(actions.draw(canvas,poses[8],233,232,1,0));
    }
    assert(Sprite::decodes==19); // bad pose remembered; other poses/idle survive
  }
  assert(Sprite::allocations==Sprite::frees);
}
