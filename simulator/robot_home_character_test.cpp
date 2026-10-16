#include <cassert>
#include <cmath>
#include <cstdint>
#include <initializer_list>

#include "RobotHomeCharacter.h"

int main(int argc, char**) {
  using C = robot_home::Character;
  using D = touch_gesture::Direction;
  // These existing identities prove missing behavior without a compile-only RED.
  // An argument isolates Down when diagnosing a failure in the preceding Right check.
  if (argc == 1) {
    robot_home::CharacterSelector selector;
    unsigned calls = 0;
    assert(selector.select(D::Right, 100, [&] { ++calls; return 0u; }) == C::Bumblebee);
    assert(calls == 0 && selector.transitionProgress(100) == 0.0f);
  }
  {
    robot_home::CharacterSelector selector;
    const C selected = selector.select(D::Down, 100, [] { return 0u; });
    assert(static_cast<unsigned>(selected) >= 9 && static_cast<unsigned>(selected) <= 16);
  }
  // Literal IDs independently define the roster contract, including old 0..8.
  const C autobots[]{C::BumblebeeFullbody, C::Optimus, C::Jazz, C::Hotrod,
                     C::Wheeljack, C::Hound, C::Ironhide, C::Ratchet};
  const C decepticons[]{C::Megatron, C::Starscream, C::Soundwave, C::Shockwave,
                        C::Thundercracker, C::Skywarp, C::Blitzwing, C::Astrotrain};
  for (unsigned i = 0; i < 8; ++i) {
    assert(static_cast<unsigned>(autobots[i]) == i + 1);
    assert(static_cast<unsigned>(decepticons[i]) == i + 9);
    robot_home::CharacterSelector selector;
    assert(selector.select(D::Up, 0, [i] { return i; }) == autobots[i]);
    selector.reset();
    assert(selector.select(D::Down, 0, [i] { return i; }) == decepticons[i]);
  }
  for (D direction : {D::Up, D::Down}) {
    const unsigned base = direction == D::Up ? 1 : 9;
    // From portrait or the opposite faction, all eight targets are reachable.
    for (unsigned current = 0; current <= 16; ++current) {
      bool reached[17]{};
      const bool inPool = current >= base && current < base + 8;
      const unsigned range = inPool ? 7 : 8;
      for (std::uint32_t sample = 0; sample < range; ++sample) {
        robot_home::CharacterSelector selector;
        if (current) selector.select(current <= 8 ? D::Up : D::Down, 10,
                                     [current] { return (current - 1) % 8; });
        assert(static_cast<unsigned>(selector.character()) == current);
        unsigned calls = 0;
        const C selected = selector.select(direction, 100, [&] { ++calls; return sample; });
        const unsigned index = static_cast<unsigned>(selected);
        assert(index >= base && index < base + 8 && index != current);
        assert(!reached[index]); reached[index] = true;
        assert(calls == 1 && selector.character() == selected);
        for (D ignored : {D::Left, D::None}) {
          assert(selector.select(ignored, 260, [&] { ++calls; return 0u; }) == selected);
          assert(calls == 1);
          assert(std::fabs(selector.transitionProgress(260) - 0.5f) < 0.001f);
        }
      }
      for (unsigned target = base; target < base + 8; ++target)
        assert(reached[target] == (target != current));
      // Returning from every role (including portrait) neither samples nor
      // preserves the old transition; it starts a fresh 320ms arrival.
      robot_home::CharacterSelector selector;
      if (current) selector.select(current <= 8 ? D::Up : D::Down, 10,
                                   [current] { return (current - 1) % 8; });
      assert(selector.select(D::Right, 100, [] { assert(false); return 0u; }) == C::Bumblebee);
      assert(selector.transitionProgress(100) == 0.0f);
      assert(std::fabs(selector.transitionProgress(260) - 0.5f) < 0.001f);
      assert(selector.transitionProgress(419) < 1.0f);
      assert(selector.transitionProgress(420) == 1.0f);
      assert(selector.select(D::Right, 300, [] { assert(false); return 0u; }) == C::Bumblebee);
      assert(selector.transitionProgress(300) == 0.0f);
    }
    // Range 8 divides 2^32: UINT32_MAX is accepted without rejecting entropy.
    robot_home::CharacterSelector selector;
    unsigned calls = 0;
    assert(static_cast<unsigned>(selector.select(direction, 100, [&] {
      ++calls; return 0xffffffffu;
    })) == base + 7);
    assert(calls == 1);
    // Range 7 rejects the top four values and accepts the prior boundary.
    const std::uint32_t samples[]{0xfffffffcu, 0xfffffffdu, 0xfffffffeu, 0xffffffffu, 0xfffffffbu};
    calls = 0;
    assert(static_cast<unsigned>(selector.select(direction, 200, [&] {
      assert(calls < 5); return samples[calls++];
    })) == base + 6);
    assert(calls == 5);
  }
  robot_home::CharacterSelector selector;
  for (D ignored : {D::Left, D::None}) {
    assert(selector.select(ignored, 100, [] { assert(false); return 0u; }) == C::Bumblebee);
    assert(selector.transitionProgress(100) == 1.0f);
  }
  selector.select(D::Right, 0xfffffff0u, [] { assert(false); return 0u; });
  assert(selector.transitionProgress(0xfffffff0u) == 0.0f);
  assert(std::fabs(selector.transitionProgress(0x90u) - 0.5f) < 0.001f);
  assert(selector.transitionProgress(0x12fu) < 1.0f);
  assert(selector.transitionProgress(0x130u) == 1.0f);
  assert(selector.transitionProgress(0x131u) == 1.0f);
  selector.select(D::Down, 100, [] { return 7u; });
  selector.reset();
  assert(selector.character() == C::Bumblebee && selector.transitionProgress(0x90u) == 1.0f);
}
