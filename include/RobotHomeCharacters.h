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
  float scale = 1.04f + 0.14f * eased;

  // Visible rim centers in the approved 300px JPEGs. Their black padding is
  // not symmetric; anchoring the bitmap midpoint makes the circles drift.
  // Calibrated against the native RGB565 renderer and guarded by pixel tests.
  float rimX = 150.0f;
  float rimY = 148.3f;
  switch (character) {
    case Character::Bumblebee: break;
    case Character::Optimus: rimX = 149.15f; break;
    case Character::Megatron: rimX = 149.58f; rimY = 147.88f; break;
    case Character::Starscream: rimX = 148.3f; rimY = 145.1f; break;
  }

  if (mood == Mood::Talking) {
    const float phase = (nowMs % 320) / 320.0f * 6.2831853f;
    const float pulse = (1.0f + std::sin(phase)) * 0.5f;
    scale += pulse * 0.010f;
  }

  // M5GFX's scaled JPEG raster lands one pixel before the geometric anchor.
  const int left = 1 + static_cast<int>(std::lround(233.0f - rimX * scale));
  // Status ink ends at y=50; the battery group starts at y=414. Center
  // the visible ring at their midpoint so both clear gaps are equal.
  const int top = 1 + static_cast<int>(std::lround(232.0f - rimY * scale));
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
