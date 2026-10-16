// SPDX-License-Identifier: MIT
#pragma once

#include <array>
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
  Megatron,
  Starscream,
  Soundwave,
  Shockwave,
  Thundercracker,
  Skywarp,
  Blitzwing,
  Astrotrain,
};

inline constexpr std::uint8_t kCharacterCount = 17;
inline constexpr std::uint8_t kAutobotCount = 8;
inline constexpr std::uint8_t kDecepticonCount = 8;
inline constexpr std::uint8_t kFullbodyCount = 16;
inline constexpr std::array<Character, 8> kAutobots{
    Character::BumblebeeFullbody, Character::Optimus, Character::Jazz,
    Character::Hotrod, Character::Wheeljack, Character::Hound,
    Character::Ironhide, Character::Ratchet};
inline constexpr std::array<Character, 8> kDecepticons{
    Character::Megatron, Character::Starscream, Character::Soundwave,
    Character::Shockwave, Character::Thundercracker, Character::Skywarp,
    Character::Blitzwing, Character::Astrotrain};

class CharacterSelector {
 public:
  template <typename RandomFn>
  Character select(touch_gesture::Direction direction, std::uint32_t nowMs,
                   RandomFn&& randomFn) {
    if (direction == touch_gesture::Direction::Left ||
        direction == touch_gesture::Direction::None) {
      return character_;
    }

    if (direction == touch_gesture::Direction::Right) {
      character_ = Character::Bumblebee;
      transitionSince_ = nowMs;
      transitioning_ = true;
      return character_;
    }

    const auto& pool = direction == touch_gesture::Direction::Up
                           ? kAutobots : kDecepticons;
    std::uint32_t current = pool.size();
    for (std::uint32_t i = 0; i < pool.size(); ++i) {
      if (pool[i] == character_) {
        current = i;
        break;
      }
    }
    const std::uint32_t range =
        current < pool.size() ? pool.size() - 1 : pool.size();
    const std::uint64_t accepted = (std::uint64_t{1} << 32) / range * range;
    std::uint32_t sample;
    do {
      sample = randomFn();
    } while (sample >= accepted);
    std::uint32_t candidate = sample % range;
    if (current < pool.size() && candidate >= current) ++candidate;
    character_ = pool[candidate];
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
