// SPDX-License-Identifier: MIT
#pragma once

#include <cstdint>

#include "TouchGesture.h"

namespace robot_home {

enum class Character : std::uint8_t {
  Bumblebee,
  BumblebeeFullbody,
  Optimus,
  Jazz,
  Hotrod,
  Wheeljack,
  Hound,
  Ironhide,
  Ratchet,
};

inline constexpr std::uint8_t kCharacterCount = 9;
inline constexpr std::uint8_t kFullbodyCount = 8;

class CharacterSelector {
 public:
  template <typename RandomFn>
  Character select(touch_gesture::Direction direction, std::uint32_t nowMs,
                   RandomFn&& randomFn) {
    if (direction == touch_gesture::Direction::Left ||
        direction == touch_gesture::Direction::None) {
      return character_;
    }

    const bool fromPortrait = character_ == Character::Bumblebee;
    const std::uint32_t range = fromPortrait ? kFullbodyCount : kFullbodyCount - 1;
    const std::uint64_t accepted = (std::uint64_t{1} << 32) / range * range;
    std::uint32_t sample;
    do {
      sample = randomFn();
    } while (sample >= accepted);
    std::uint32_t candidate = sample % range;
    if (!fromPortrait && candidate >= static_cast<std::uint32_t>(character_) - 1) ++candidate;
    character_ = static_cast<Character>(candidate + 1);
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
