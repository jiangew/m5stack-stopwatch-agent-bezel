// SPDX-License-Identifier: MIT
#pragma once
#include <algorithm>
#include <cmath>
#include <cstdint>
#include "RobotHomeArtData.h"
#include "RobotHomeCharacter.h"
#include "RobotHomeInteraction.h"
#include "RobotHomePortraitCache.h"

namespace robot_home {
namespace character_art {
using Asset = PortraitImage;
inline Asset assetFor(Character character) {
  switch(character) {
    case Character::Bumblebee: return {art_data::kBumblebeeJpg,art_data::kBumblebeeJpgSize};
    case Character::Optimus: return {art_data::kOptimusJpg,art_data::kOptimusJpgSize};
    case Character::Ironman: return {art_data::kIronmanJpg,art_data::kIronmanJpgSize};
    case Character::Spiderman: return {art_data::kSpidermanJpg,art_data::kSpidermanJpgSize};
  }
  return {art_data::kBumblebeeJpg,art_data::kBumblebeeJpgSize};
}
}

template<class Surface>
void renderCharacter(Surface& surface, Character character, Mood mood,
                     std::uint32_t elapsed, float transitionProgress) {
  const auto asset=character_art::assetFor(character);
  const float p=std::max(0.0f,std::min(1.0f,transitionProgress));
  float scale=1.04f+.14f*(1-(1-p)*(1-p));
  float angle=0;
  if(mood==Mood::Press) scale*=.97f;
  if(mood==Mood::Skill) {
    const float t=std::min(1.0f,elapsed/420.0f);
    const float spring=std::sin(t*6.2831853f)*std::exp(-3*t);
    scale*=1+.045f*spring;
    if(character==Character::Spiderman) angle=5*spring;
  }
  // All source portraits share the same center. Their black margin leaves
  // status and battery safe even at the largest rebound/rotation.
  surface.drawPortrait(asset.bytes,asset.size,233,232,scale,angle);
}
}
