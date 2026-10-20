// SPDX-License-Identifier: MIT
#pragma once
#include <algorithm>
#include <cmath>
#include <cstdint>
#include "RobotHomeArtData.h"
#include "RobotHomeActionArtData.h"
#include "RobotHomeCharacter.h"
#include "RobotHomeInteraction.h"
#include "RobotHomeMotion.h"
#include "RobotHomeImu.h"
#include "RobotHomePortraitCache.h"

namespace robot_home {
namespace character_art {
using Asset = PortraitImage;
inline Asset assetFor(Character character) {
  switch(character) {
    case Character::Bumblebee: return {art_data::kBumblebeeJpg,art_data::kBumblebeeJpgSize};
    case Character::BumblebeeFullbody: return {art_data::kBumblebeeFullbodyJpg,art_data::kBumblebeeFullbodyJpgSize};
    case Character::Optimus: return {art_data::kOptimusJpg,art_data::kOptimusJpgSize};
    case Character::Jazz: return {art_data::kJazzJpg,art_data::kJazzJpgSize};
    case Character::Hotrod: return {art_data::kHotrodJpg,art_data::kHotrodJpgSize};
    case Character::Wheeljack: return {art_data::kWheeljackJpg,art_data::kWheeljackJpgSize};
    case Character::Hound: return {art_data::kHoundJpg,art_data::kHoundJpgSize};
    case Character::Ironhide: return {art_data::kIronhideJpg,art_data::kIronhideJpgSize};
    case Character::Ratchet: return {art_data::kRatchetJpg,art_data::kRatchetJpgSize};
    case Character::Megatron: return {art_data::kMegatronJpg,art_data::kMegatronJpgSize};
    case Character::Starscream: return {art_data::kStarscreamJpg,art_data::kStarscreamJpgSize};
    case Character::Soundwave: return {art_data::kSoundwaveJpg,art_data::kSoundwaveJpgSize};
    case Character::Shockwave: return {art_data::kShockwaveJpg,art_data::kShockwaveJpgSize};
    case Character::Thundercracker: return {art_data::kThundercrackerJpg,art_data::kThundercrackerJpgSize};
    case Character::Skywarp: return {art_data::kSkywarpJpg,art_data::kSkywarpJpgSize};
    case Character::Blitzwing: return {art_data::kBlitzwingJpg,art_data::kBlitzwingJpgSize};
    case Character::Astrotrain: return {art_data::kAstrotrainJpg,art_data::kAstrotrainJpgSize};
  }
  return {art_data::kBumblebeeJpg,art_data::kBumblebeeJpgSize};
}

struct ActionAsset { Character character; unsigned pose; Asset image; };
inline const ActionAsset kActions[] = {
  {Character::BumblebeeFullbody,1,{art_data::kBumblebeeFullbodyPose1Jpg,art_data::kBumblebeeFullbodyPose1JpgSize}},
  {Character::BumblebeeFullbody,2,{art_data::kBumblebeeFullbodyPose2Jpg,art_data::kBumblebeeFullbodyPose2JpgSize}},
  {Character::Optimus,1,{art_data::kOptimusPose1Jpg,art_data::kOptimusPose1JpgSize}},
  {Character::Optimus,2,{art_data::kOptimusPose2Jpg,art_data::kOptimusPose2JpgSize}},
  {Character::Jazz,1,{art_data::kJazzPose1Jpg,art_data::kJazzPose1JpgSize}},
  {Character::Hotrod,1,{art_data::kHotrodPose1Jpg,art_data::kHotrodPose1JpgSize}},
  {Character::Wheeljack,1,{art_data::kWheeljackPose1Jpg,art_data::kWheeljackPose1JpgSize}},
  {Character::Hound,1,{art_data::kHoundPose1Jpg,art_data::kHoundPose1JpgSize}},
  {Character::Ironhide,1,{art_data::kIronhidePose1Jpg,art_data::kIronhidePose1JpgSize}},
  {Character::Ratchet,1,{art_data::kRatchetPose1Jpg,art_data::kRatchetPose1JpgSize}},
  {Character::Megatron,1,{art_data::kMegatronPose1Jpg,art_data::kMegatronPose1JpgSize}},
  {Character::Starscream,1,{art_data::kStarscreamPose1Jpg,art_data::kStarscreamPose1JpgSize}},
  {Character::Soundwave,1,{art_data::kSoundwavePose1Jpg,art_data::kSoundwavePose1JpgSize}},
  {Character::Shockwave,1,{art_data::kShockwavePose1Jpg,art_data::kShockwavePose1JpgSize}},
  {Character::Thundercracker,1,{art_data::kThundercrackerPose1Jpg,art_data::kThundercrackerPose1JpgSize}},
  {Character::Skywarp,1,{art_data::kSkywarpPose1Jpg,art_data::kSkywarpPose1JpgSize}},
  {Character::Blitzwing,1,{art_data::kBlitzwingPose1Jpg,art_data::kBlitzwingPose1JpgSize}},
  {Character::Astrotrain,1,{art_data::kAstrotrainPose1Jpg,art_data::kAstrotrainPose1JpgSize}},
};
inline constexpr std::size_t kActionCount=sizeof(kActions)/sizeof(kActions[0]);
inline Asset actionFor(Character character,unsigned pose) {
  for(const auto& action:kActions)
    if(action.character==character&&action.pose==pose)return action.image;
  return assetFor(character);
}
inline Asset idleForAsset(Asset image) {
  for(const auto& action:kActions)
    if(action.image.bytes==image.bytes)return assetFor(action.character);
  return image;
}
}

template<class Surface>
void renderCharacter(Surface& surface, Character character, Mood mood,
                     std::uint32_t elapsed, float transitionProgress,
                     imu::Pose posture = {}, bool notificationBadgeVisible = false) {
  const auto motion=motionFor(character,mood,elapsed);
  const auto asset=character_art::actionFor(character,motion.pose);
  const float p=std::max(0.0f,std::min(1.0f,transitionProgress));
  float scale=1.04f+.14f*(1-(1-p)*(1-p));
  scale*=motion.scale;
  if(mood==Mood::Press||mood==Mood::Skill)posture={};
  scale*=posture.scale;
  // All source portraits share the same center. Their black margin leaves
  // status and battery safe even at the largest rebound/rotation.
  surface.drawPortrait(asset.bytes,asset.size,233+posture.x,232+motion.offsetY+posture.y,
                       scale,motion.angle+posture.angle,notificationBadgeVisible);
}
}
