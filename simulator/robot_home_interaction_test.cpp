#include <cassert>
#include "RobotHomeInteraction.h"
int main() {
  using namespace robot_home;
  Animation a;
  a.react(Mood::Happy, 100);
  assert(a.mood(2499) == Mood::Happy);
  a.react(Mood::Sleep, 2499);
  assert(a.mood(2500) == Mood::Sleep);
  assert(a.mood(4899) == Mood::Idle);
  a.react(Mood::Surprise, 0xfffffff0u);
  assert(a.mood(2383) == Mood::Surprise);
  assert(a.mood(2384) == Mood::Idle);
  assert(!a.frameDue(0, false));
  assert(a.frameDue(0, true));
  assert(!a.frameDue(49, true));
  assert(a.frameDue(50, true));
  for (unsigned i=0; i<50; ++i) {
    const auto before=a.mood(500);
    a.random(500,i);
    assert(a.mood(500)!=before);
  }
  Tap tap;
  tap.begin(200,200,0,true); assert(tap.finish(200,200,499,52));
  tap.begin(200,200,0,true); assert(!tap.finish(200,200,500,52));
  tap.begin(200,200,0,false); assert(!tap.finish(200,200,100,52));
  tap.begin(87,200,0,true); assert(!tap.finish(200,200,100,52));
  tap.begin(200,200,0,true); assert(!tap.finish(379,200,100,52));
  tap.begin(200,200,0,true); tap.move(253,200,52);
  assert(!tap.finish(200,200,100,52));
  tap.begin(200,200,0,true);tap.cancel();assert(!tap.finish(200,200,10,52));
}
