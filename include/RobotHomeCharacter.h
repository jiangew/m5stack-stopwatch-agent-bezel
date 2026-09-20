// SPDX-License-Identifier: MIT
#pragma once

#include <cstdint>

#include "TouchGesture.h"

namespace robot_home {

enum class Character : std::uint8_t {
  Bumblebee,
  Optimus,
  Megatron,
  Starscream,
};

class CharacterSelector {
 public:
  Character select(touch_gesture::Direction direction, std::uint32_t nowMs) {
    const Character target = targetFor(direction);
    if (direction == touch_gesture::Direction::Left ||
        direction == touch_gesture::Direction::None) {
      return character_;
    }
    character_ = character_ == target ? Character::Bumblebee : target;
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

  static constexpr Character targetFor(touch_gesture::Direction direction) {
    switch (direction) {
      case touch_gesture::Direction::Up:
        return Character::Optimus;
      case touch_gesture::Direction::Down:
        return Character::Megatron;
      case touch_gesture::Direction::Right:
        return Character::Starscream;
      case touch_gesture::Direction::Left:
      case touch_gesture::Direction::None:
        return Character::Bumblebee;
    }
    return Character::Bumblebee;
  }

  Character character_ = Character::Bumblebee;
  std::uint32_t transitionSince_ = 0;
  bool transitioning_ = false;
};

}  // namespace robot_home
