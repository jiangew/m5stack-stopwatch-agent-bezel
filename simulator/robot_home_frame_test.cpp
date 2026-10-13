#include <cassert>
#include "RobotHomeFrame.h"
int main() {
  robot_home::FrameClock clock;
  assert(clock.due(100, true, false, false)); // first visible frame
  clock.presented(100, false);
  assert(!clock.due(10000, true, false, false)); // idle is quiet
  assert(clock.due(101, true, true, true)); // input bypasses cadence
  clock.presented(101, true);
  assert(!clock.due(120, true, true, false));
  assert(clock.due(135, true, true, false));
  clock.presented(135, true);
  assert(clock.due(136, true, false, false)); // repaint final resting state
  clock.presented(136, false);
  assert(!clock.due(10000, true, false, false));
  assert(clock.due(10000, true, false, true)); // battery/link changed
  assert(!clock.due(10001, false, true, true));
  assert(clock.due(10002, true, false, false)); // waking must repaint
  clock.presented(0xfffffff0u, true);
  assert(!clock.due(0u, true, true, false));
  assert(clock.due(18u, true, true, false));
}
