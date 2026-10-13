#include <cassert>
#include <cmath>
#include <cstdint>
#include <initializer_list>
#include <limits>

#include "RobotHomeCharacter.h"

int main() {
  using C = robot_home::Character;
  using D = touch_gesture::Direction;
  const C characters[]{C::Bumblebee, C::Optimus, C::Ironman, C::Spiderman};
  const C alternatives[][3]{
      {C::Optimus, C::Ironman, C::Spiderman},
      {C::Bumblebee, C::Ironman, C::Spiderman},
      {C::Bumblebee, C::Optimus, C::Spiderman},
      {C::Bumblebee, C::Optimus, C::Ironman},
  };

  // Every selectable direction reaches each other character, never itself.
  for (unsigned current = 0; current < 4; ++current) {
    for (D direction : {D::Up, D::Down, D::Right}) {
      for (std::uint32_t sample = 0; sample < 9; ++sample) {
        robot_home::CharacterSelector selector;
        if (current != 0) {
          selector.select(D::Up, 10, [current] { return current - 1; });
        }
        assert(selector.character() == characters[current]);
        unsigned calls = 0;
        const C selected = selector.select(direction, 100, [&] {
          ++calls;
          return sample;
        });
        assert(selected == alternatives[current][sample % 3]);
        assert(selected != characters[current]);
        assert(calls == 1);
        assert(selector.character() == selected);

        // Workspace and absent gestures leave selection and timing alone.
        for (D ignored : {D::Left, D::None}) {
          assert(selector.select(ignored, 260, [&] {
            ++calls;
            return 0u;
          }) == selected);
          assert(calls == 1);
          assert(std::fabs(selector.transitionProgress(260) - 0.5f) < 0.001f);
        }
      }
    }
  }

  robot_home::CharacterSelector selector;
  const std::uint32_t samples[]{std::numeric_limits<std::uint32_t>::max(),
      std::numeric_limits<std::uint32_t>::max(), 0xfffffffeu};
  unsigned calls = 0;
  assert(selector.select(D::Down, 100, [&] {
    assert(calls < 3);
    return samples[calls++];
  }) == C::Spiderman);
  assert(calls == 3);  // UINT32_MAX is rejected; the last value is valid.

  selector.reset();
  assert(selector.character() == C::Bumblebee);
  assert(selector.transitionProgress(0) == 1.0f);
  assert(selector.select(D::Right, 0xfffffff0u, [] { return 1u; }) == C::Ironman);
  assert(selector.transitionProgress(0xfffffff0u) == 0.0f);
  assert(std::fabs(selector.transitionProgress(0x90u) - 0.5f) < 0.001f);
  assert(selector.transitionProgress(0x12fu) < 1.0f);
  assert(selector.transitionProgress(0x130u) == 1.0f);
  assert(selector.transitionProgress(0x131u) == 1.0f);
  selector.reset();
  assert(selector.character() == C::Bumblebee);
  assert(selector.transitionProgress(0x90u) == 1.0f);
}
