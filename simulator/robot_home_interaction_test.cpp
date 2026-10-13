#include <cassert>
#include <cstdint>
#include <initializer_list>

#include "RobotHomeInteraction.h"

void testTap() {
  using namespace robot_home;
  // Portrait corners belong to the interactive region; outer edges do not.
  for (int x : {64, 402}) {
    for (int y : {64, 398}) {
      assert(inHead(x, y));
      Tap tap;
      tap.begin(x, y, 100, true);
      assert(tap.eligible());
      assert(tap.finish(x, y, 599, 52));
      assert(!tap.eligible());
    }
  }
  assert(!inHead(63, 200));
  assert(!inHead(403, 200));
  assert(!inHead(200, 63));
  assert(!inHead(200, 399));

  Tap tap;
  for (std::uint32_t start : {100u, 0xfffffff0u}) {
    tap.begin(200, 200, start, true);
    tap.move(251, 200, 52);
    assert(tap.eligible());
    assert(tap.finish(200, 200, start + 499, 52));
    tap.begin(200, 200, start, true);
    assert(!tap.finish(200, 200, start + 500, 52));
    tap.begin(200, 200, start, true);
    assert(!tap.finish(200, 200, start + 501, 52));

    for (const auto delta : {52, -52}) {
      tap.begin(200, 200, start, true);
      tap.move(200 + delta, 200, 52);
      assert(!tap.eligible());
      tap.move(200, 200, 52);
      assert(!tap.finish(200, 200, start + 100, 52));
      tap.begin(200, 200, start, true);
      tap.move(200, 200 + delta, 52);
      assert(!tap.eligible());
      assert(!tap.finish(200, 200, start + 100, 52));
    }
    tap.begin(200, 200, start, true);
    tap.move(237, 237, 52);  // Diagonal displacement exceeds 52px.
    assert(!tap.finish(200, 200, start + 100, 52));

    // Short excursions beyond each edge cancel, even after return.
    for (const auto edge : {0, 1, 2, 3}) {
      const int x = edge == 0 ? 64 : edge == 1 ? 402 : 200;
      const int y = edge == 2 ? 64 : edge == 3 ? 398 : 200;
      tap.begin(x, y, start, true);
      tap.move(x + (edge == 0 ? -1 : edge == 1 ? 1 : 0),
          y + (edge == 2 ? -1 : edge == 3 ? 1 : 0), 52);
      assert(!tap.eligible());
      tap.move(x, y, 52);
      assert(!tap.finish(x, y, start + 100, 52));
    }

    tap.begin(200, 200, start, false);
    assert(!tap.eligible());
    tap.move(201, 201, 52);
    assert(!tap.finish(200, 200, start + 100, 52));
    tap.begin(63, 200, start, true);
    tap.move(64, 200, 52);
    assert(!tap.finish(64, 200, start + 100, 52));
    tap.begin(200, 200, start, true);
    tap.cancel();
    assert(!tap.eligible());
    assert(!tap.finish(200, 200, start + 1, 52));
  }
}

int main() {
  using namespace robot_home;
  testTap();
  Animation animation;
  assert(animation.mood(0) == Mood::Idle);
  assert(!animation.active(0));
  assert(!animation.release(0));
  for (std::uint32_t start : {100u, 0xfffffff0u}) {
    animation.press(start);
    assert(animation.mood(start) == Mood::Press);
    assert(animation.elapsed(start) == 0);
    assert(animation.active(start));
    assert(animation.mood(start + 499) == Mood::Press);
    assert(animation.mood(start + 500) == Mood::Idle);
    assert(!animation.active(start + 500));
    assert(!animation.release(start + 500));
    assert(animation.mood(start + 501) == Mood::Idle);

    animation.press(start);
    assert(animation.release(start + 499));
    assert(animation.mood(start + 499) == Mood::Skill);
    assert(animation.elapsed(start + 499) == 0);
    assert(animation.active(start + 918));
    assert(animation.mood(start + 918) == Mood::Skill);
    assert(!animation.release(start + 600));
    assert(animation.elapsed(start + 600) == 101); // Release cannot restart skill.
    assert(animation.mood(start + 919) == Mood::Idle);
    assert(!animation.active(start + 919));

    animation.press(start);
    assert(animation.release(start + 10));
    animation.press(start + 20);  // Rapid repeat interrupts skill immediately.
    assert(animation.mood(start + 20) == Mood::Press);
    assert(animation.elapsed(start + 20) == 0);
    assert(animation.release(start + 21));
    assert(animation.mood(start + 21) == Mood::Skill);
    assert(animation.elapsed(start + 21) == 0);
    animation.cancel();
    assert(!animation.active(start + 22));
    assert(animation.mood(start + 22) == Mood::Idle);
    assert(!animation.release(start + 22));
    animation.press(start + 30);
    animation.cancel();
    assert(!animation.release(start + 31));

    for (Mood mood : {Mood::Happy, Mood::Surprise, Mood::Sleep, Mood::Connect}) {
      animation.react(mood, start);
      assert(animation.mood(start) == mood);
      assert(animation.mood(start + 2399) == mood);
      assert(animation.mood(start + 2400) == Mood::Idle);
      assert(!animation.release(start + 1));
    }
    animation.react(Mood::Idle, start);
    assert(!animation.active(start));
  }

  // Existing idle reactions remain usable; scheduling lives in FrameClock.
  animation.cancel();
  for (unsigned i = 0; i < 50; ++i) {
    const auto before = animation.mood(500);
    animation.random(500, i);
    assert(animation.mood(500) != before);
  }
}
