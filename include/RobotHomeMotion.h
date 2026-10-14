// SPDX-License-Identifier: MIT
#pragma once
#include <cmath>
#include "RobotHomeCharacter.h"
#include "RobotHomeInteraction.h"

namespace robot_home {
struct Motion {
  unsigned pose = 0;
  float scale = 1;
  float offsetY = 0;
  float angle = 0;
};

// No scheduling or allocations here: input can interrupt at any sampled time.
inline Motion motionFor(Character character, Mood mood, std::uint32_t elapsed) {
  Motion motion;
  if(mood==Mood::Press) { motion.scale=.97f;return motion; }
  if(mood!=Mood::Skill||elapsed>=kResponseDurationMs)return motion;
  const float t=elapsed/static_cast<float>(kResponseDurationMs);
  const float envelope=std::sin(t*3.14159265f);
  switch(character) {
    case Character::Bumblebee:
      motion.scale+=.025f*envelope;
      motion.offsetY=3*envelope;
      motion.angle=-3*std::sin(t*6.2831853f)*envelope;
      break;
    case Character::BumblebeeFullbody:
      motion.pose=elapsed<134?1:elapsed<267?2:elapsed<400?1:elapsed<534?2:0;
      motion.offsetY=-3.5f*envelope;
      break;
    case Character::Optimus:
      motion.pose=elapsed<134?1:elapsed<400?2:elapsed<534?1:0;
      motion.offsetY=-1.5f*envelope;
      break;
    case Character::Jazz:
      motion.pose=elapsed<500?1:0;
      motion.angle=-2*envelope;
      motion.offsetY=-2*envelope;
      break;
    case Character::Hotrod:
      motion.pose=elapsed<500?1:0;
      motion.scale+=.025f*envelope;
      motion.angle=-2*envelope;
      motion.offsetY=-3*envelope;
      break;
    case Character::Wheeljack:
      motion.pose=elapsed<500?1:0;
      motion.angle=1.5f*envelope;
      break;
    case Character::Hound:
      motion.pose=elapsed<500?1:0;
      motion.offsetY=1.5f*envelope;
      break;
    case Character::Ironhide:
      motion.pose=elapsed<500?1:0;
      motion.scale+=.035f*envelope;
      break;
    case Character::Ratchet:
      motion.pose=elapsed<500?1:0;
      motion.angle=-1.5f*envelope;
      break;
  }
  return motion;
}
}
