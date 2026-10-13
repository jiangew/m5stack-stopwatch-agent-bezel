// SPDX-License-Identifier: MIT
#pragma once

#include <cstdint>
#include <limits>

#include "TouchGesture.h"

namespace robot_home {

enum class Character : std::uint8_t {
  Bumblebee,
  Optimus,
  Ironman,
  Spiderman,
};

class CharacterSelector {
 public:
  template <typename RandomFn>
  Character select(touch_gesture::Direction direction, std::uint32_t nowMs,
                   RandomFn&& randomFn) {
    if (direction == touch_gesture::Direction::Left ||
        direction == touch_gesture::Direction::None) {
      return character_;
    }

    // 2^32 - 1 is divisible by three: rejecting the one excess value makes
    // each candidate equally likely without consuming entropy for Left/None.
    std::uint32_t sample;
    do {
      sample = randomFn();
    } while (sample == std::numeric_limits<std::uint32_t>::max());
    const auto excluded = static_cast<std::uint32_t>(character_);
    auto candidate = sample % 3;
    if (candidate >= excluded) ++candidate;
    character_ = static_cast<Character>(candidate);
    transitionSince_ = nowMs;
    transitioning_ = true;
    return character_;
  }

  void reset() {
    character_ = Character::Bumblebee;
    transitioning_ = false;
  }

  Character character() const { return character_; }

  float transitionProgress(std::uint32_t nowMs) const {
    if (!transitioning_) return 1.0f;
    const std::uint32_t elapsed = nowMs - transitionSince_;
    if (elapsed >= kTransitionMs) return 1.0f;
    return static_cast<float>(elapsed) / static_cast<float>(kTransitionMs);
  }

 private:
  static constexpr std::uint32_t kTransitionMs = 320;

  Character character_ = Character::Bumblebee;
  std::uint32_t transitionSince_ = 0;
  bool transitioning_ = false;
};

}  // namespace robot_home
