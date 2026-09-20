// SPDX-License-Identifier: MIT
#pragma once

#include <cmath>
#include <cstdint>

#include "RobotHomeArtData.h"
#include "RobotHomeCharacter.h"
#include "RobotHomeInteraction.h"

namespace robot_home::character_art {

struct Asset {
  const std::uint8_t* bytes;
  std::uint32_t size;
};

inline Asset assetFor(Character character) {
  switch (character) {
    case Character::Bumblebee:
      return {art_data::kBumblebeeJpg,
              static_cast<std::uint32_t>(art_data::kBumblebeeJpgSize)};
    case Character::Optimus:
      return {art_data::kOptimusJpg,
              static_cast<std::uint32_t>(art_data::kOptimusJpgSize)};
    case Character::Megatron:
      return {art_data::kMegatronJpg,
              static_cast<std::uint32_t>(art_data::kMegatronJpgSize)};
    case Character::Starscream:
      return {art_data::kStarscreamJpg,
              static_cast<std::uint32_t>(art_data::kStarscreamJpgSize)};
  }
  return {art_data::kBumblebeeJpg,
          static_cast<std::uint32_t>(art_data::kBumblebeeJpgSize)};
}

template <class Surface>
void render(Surface& surface, Character character, Mood mood,
            std::uint32_t nowMs, float transitionProgress) {
  const Asset asset = assetFor(character);
  const float boundedProgress = transitionProgress < 0.0f
                                    ? 0.0f
                                    : (transitionProgress > 1.0f
                                           ? 1.0f
                                           : transitionProgress);
  const float eased = 1.0f -
                      (1.0f - boundedProgress) * (1.0f - boundedProgress);
  float scale = 0.82f + 0.12f * eased;
  int centerY = 220;

  if (mood == Mood::Talking) {
    const float phase = (nowMs % 320) / 320.0f * 6.2831853f;
    const float pulse = (1.0f + std::sin(phase)) * 0.5f;
    centerY -= static_cast<int>(pulse * 4.0f);
    scale += pulse * 0.010f;
  }

  const int left = 233 - static_cast<int>(150.0f * scale);
  const int top = centerY - static_cast<int>(150.0f * scale);
  surface.drawJpg(asset.bytes, asset.size, left, top, 0, 0, 0, 0,
                  scale, scale);
}

}  // namespace robot_home::character_art

namespace robot_home {

template <class Surface>
void renderCharacter(Surface& surface, Character character, Mood mood,
                     std::uint32_t nowMs, float transitionProgress) {
  character_art::render(surface, character, mood, nowMs, transitionProgress);
}

}  // namespace robot_home
