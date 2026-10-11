#include <cassert>
#include <initializer_list>
#include "RobotHomeCharacter.h"
#include "RobotHomeInteraction.h"
int main() {
  using namespace robot_home;
  static_assert(kBlinkDurationMs == 1320);
  for (std::uint32_t start : {100u, 0xfffffff0u}) {
    Animation blink;
    assert(blink.blink(start));
    unsigned closures = 0;
    BlinkFrame previous = BlinkFrame::Open;
    // Test every millisecond, including all half/closed/open boundaries and
    // both open gaps. Retapping throughout must preserve the original start.
    for (std::uint32_t ms = 0; ms < 1320; ++ms) {
      assert(blink.mood(start + ms) == Mood::Blink);
      assert(!blink.blink(start + ms));
      assert(blink.elapsed(start + ms) == ms);
      const auto phase = ms % 480;
      const auto expected = phase < 70 ? BlinkFrame::Half
          : phase < 230 ? BlinkFrame::Closed
          : phase < 360 ? BlinkFrame::Half : BlinkFrame::Open;
      const auto actual = blinkFrame(blink.elapsed(start + ms));
      assert(actual == expected);
      if (actual == BlinkFrame::Closed && previous != actual) ++closures;
      previous = actual;
    }
    assert(closures == 3);
    assert(blink.mood(start + 1320) == Mood::Idle);
    assert(blink.mood(start + 1800) == Mood::Idle); // no queued replay
    assert(blinkFrame(1320) == BlinkFrame::Open);
    assert(blinkFrame(1440) == BlinkFrame::Open); // no fourth blink
    assert(blinkFrame(0xffffffffu) == BlinkFrame::Open);
    assert(blink.blink(start + 1800)); // next independent tap is accepted
    assert(blink.elapsed(start + 1800) == 0);
  }
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

  CharacterSelector characters;
  characters.select(touch_gesture::Direction::Down,100);
  assert(characters.character()==Character::Megatron);
  characters.reset();assert(characters.character()==Character::Bumblebee);
}
