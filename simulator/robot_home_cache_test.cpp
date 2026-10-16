#include <cassert>
#include <cstdint>
#include <initializer_list>
#include "RobotHomePortraitCache.h"
struct Canvas {};
struct Sprite {
  inline static int allocations=0, frees=0, decodes=0, draws=0, budget=17;
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
  const std::uint8_t bytes[]={1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17};
  robot_home::PortraitImage images[17];
  for(int i=0;i<17;++i)images[i]={bytes+i,1};
  Canvas canvas;
  {
    robot_home::PortraitCache<Sprite,17> cache;
    cache.prepare(images,17);
    assert(Sprite::decodes==17);
    cache.prepare(images,17);assert(Sprite::decodes==17);
    for(int i=0;i<170;++i) assert(cache.draw(canvas,images[i%17],233,232,1.18f,0));
    assert(Sprite::decodes==17&&Sprite::draws==170);
    const std::uint8_t unknown[]={8};
    assert(!cache.draw(canvas,{unknown,1},233,232,1,0));
    cache.clear();assert(Sprite::frees==17);
    cache.prepare(images,17);assert(Sprite::decodes==34);
  }
  assert(Sprite::frees==34);
  for(int budget:{7,1}) {
    reset(budget);
    {
      robot_home::PortraitCache<Sprite,17> cache;
      cache.prepare(images,17);
      assert(Sprite::allocations-Sprite::frees==1);
      for(int i=0;i<17;++i) {
        assert(cache.draw(canvas,images[i],233,232,1,0));
        const int decoded=Sprite::decodes;
        for(int repeat=0;repeat<50;++repeat)assert(cache.draw(canvas,images[i],233,232,1,0));
        assert(Sprite::decodes==decoded);
      }
      assert(cache.draw(canvas,images[7],233,232,1,0));
      Sprite::badImage=bytes+16;
      assert(!cache.draw(canvas,images[16],233,232,1,0));
      const int decoded=Sprite::decodes;
      for(int i=0;i<50;++i) assert(!cache.draw(canvas,images[16],233,232,1,0));
      assert(Sprite::decodes==decoded);
      assert(cache.draw(canvas,images[7],233,232,1,0));
      assert(Sprite::decodes==decoded+1); // restore overwritten reused pixels
    }
  }
  reset(0);
  {
    robot_home::PortraitCache<Sprite,17> cache;
    cache.prepare(images,17);
    for(const auto& image:images)for(int i=0;i<10;++i)assert(!cache.draw(canvas,image,233,232,1,0));
    assert(Sprite::decodes==0&&Sprite::allocations==0);
  }
  reset(17);Sprite::badImage=bytes+16;
  {
    robot_home::PortraitCache<Sprite,17> cache;
    cache.prepare(images,17);assert(Sprite::decodes==17);
    for(int i=0;i<50;++i)assert(!cache.draw(canvas,images[16],233,232,1,0));
    for(int i=0;i<16;++i)assert(cache.draw(canvas,images[i],233,232,1,0));
    assert(Sprite::decodes==17);
  }
  assert(Sprite::allocations==Sprite::frees&&Sprite::frees==17);
  const std::uint8_t actionBytes[]={18,19};
  robot_home::PortraitImage poses[2]={{actionBytes,1},{actionBytes+1,1}};
  // Partial action allocation never evicts the seventeen already prepared idles.
  for(int budget=17;budget<19;++budget) {
    reset(budget);
    {
      robot_home::PortraitCache<Sprite,17> idle;
      robot_home::PortraitCache<Sprite,2> actions;
      idle.prepare(images,17);actions.prepare(poses,2,false);
      assert(Sprite::allocations-Sprite::frees==17);
      const int decoded=Sprite::decodes,allocated=Sprite::allocations;
      for(int i=0;i<100;++i) {
        assert(!actions.draw(canvas,poses[i%2],233,232,1,0));
        assert(idle.draw(canvas,images[i%17],233,232,1,0));
        actions.prepare(poses,2,false);
      }
      assert(Sprite::decodes==decoded&&Sprite::allocations==allocated);
    }
    assert(Sprite::allocations==Sprite::frees);
  }
  reset(19);
  {
    robot_home::PortraitCache<Sprite,17> idle;
    robot_home::PortraitCache<Sprite,2> actions;
    idle.prepare(images,17);actions.prepare(poses,2,false);
    assert(Sprite::allocations-Sprite::frees==19&&Sprite::decodes==19);
    for(int i=0;i<100;++i)assert(actions.draw(canvas,poses[i%2],233,232,1,0));
    assert(Sprite::decodes==19);
  }
  assert(Sprite::allocations==Sprite::frees);
  reset(19);Sprite::badImage=actionBytes+1;
  {
    robot_home::PortraitCache<Sprite,17> idle;
    robot_home::PortraitCache<Sprite,2> actions;
    idle.prepare(images,17);actions.prepare(poses,2,false);
    assert(Sprite::decodes==19);
    for(int i=0;i<100;++i) {
      assert(!actions.draw(canvas,poses[1],233,232,1,0));
      assert(idle.draw(canvas,images[16],233,232,1,0));
      assert(actions.draw(canvas,poses[0],233,232,1,0));
    }
    assert(Sprite::decodes==19);
  }
  assert(Sprite::allocations==Sprite::frees);
}
