#include <cassert>
#include <cmath>
#include <cstdint>
#include <initializer_list>

#include "RobotHomeCharacter.h"

int main() {
  using C = robot_home::Character;
  using D = touch_gesture::Direction;
  // Literal numeric identities let this fail behaviorally against the old roster.
  for (D direction : {D::Up, D::Down, D::Right}) {
    for (std::uint32_t sample = 0; sample < 8; ++sample) {
      robot_home::CharacterSelector selector;
      unsigned calls = 0;
      const C selected = selector.select(direction, 100, [&] { ++calls; return sample; });
      assert(static_cast<unsigned>(selected) == sample + 1);
      assert(calls == 1 && selected != C::Bumblebee);
    }
    for (unsigned current = 1; current <= 8; ++current) {
      bool reached[9]{};
      for (std::uint32_t sample = 0; sample < 7; ++sample) {
        robot_home::CharacterSelector selector;
        selector.select(D::Up, 10, [current] { return current - 1; });
        assert(static_cast<unsigned>(selector.character()) == current);
        unsigned calls = 0;
        const C selected = selector.select(direction, 100, [&] { ++calls; return sample; });
        const unsigned index = static_cast<unsigned>(selected);
        assert(index >= 1 && index <= 8 && index != current);
        assert(!reached[index]);
        reached[index] = true;
        assert(calls == 1 && selector.character() == selected);
        for (D ignored : {D::Left, D::None}) {
          assert(selector.select(ignored, 260, [&] { ++calls; return 0u; }) == selected);
          assert(calls == 1);
          assert(std::fabs(selector.transitionProgress(260) - 0.5f) < 0.001f);
        }
      }
      for (unsigned body = 1; body <= 8; ++body) assert(reached[body] == (body != current));
    }
  }
  // Range 8 divides 2^32: UINT32_MAX is accepted with one entropy call.
  robot_home::CharacterSelector selector;
  unsigned calls = 0;
  assert(static_cast<unsigned>(selector.select(D::Down, 100, [&] {
    ++calls; return 0xffffffffu;
  })) == 8);
  assert(calls == 1);
  // Range 7 rejects the top four samples and accepts the prior boundary.
  const std::uint32_t range7[]{0xfffffffcu, 0xfffffffdu, 0xfffffffeu, 0xffffffffu, 0xfffffffbu};
  calls = 0;
  assert(static_cast<unsigned>(selector.select(D::Right, 200, [&] {
    assert(calls < 5); return range7[calls++];
  })) == 7);
  assert(calls == 5);
  selector.reset();
  assert(selector.character() == C::Bumblebee && selector.transitionProgress(0) == 1.0f);
  for (D ignored : {D::Left, D::None}) {
    assert(selector.select(ignored, 100, [] { assert(false); return 0u; }) == C::Bumblebee);
    assert(selector.transitionProgress(100) == 1.0f);
  }
  assert(static_cast<unsigned>(selector.select(D::Right, 0xfffffff0u, [] { return 1u; })) == 2);
  assert(selector.transitionProgress(0xfffffff0u) == 0.0f);
  assert(std::fabs(selector.transitionProgress(0x90u) - 0.5f) < 0.001f);
  assert(selector.transitionProgress(0x12fu) < 1.0f);
  assert(selector.transitionProgress(0x130u) == 1.0f);
  assert(selector.transitionProgress(0x131u) == 1.0f);
  selector.reset();
  assert(selector.character() == C::Bumblebee && selector.transitionProgress(0x90u) == 1.0f);
}
