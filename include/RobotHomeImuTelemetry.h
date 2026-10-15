// SPDX-License-Identifier: MIT
#pragma once
#include "RobotHomeImu.h"

namespace robot_home::imu {
// Main-loop owned; copied into the BLE snapshot. No raw audio or host content.
struct Telemetry {
  Sample sample;
  Pose pose;
  Phase phase=Phase::Calibrating;
  Event event=Event::None;
  bool enabled=true, available=false, active=false, sleeping=false;
  std::uint32_t now=0, samples=0, errors=0, pickups=0, settles=0;
  std::uint32_t gapMaxMs=0, readMaxUs=0, readMeanUs=0;
  std::uint32_t eventAt=0, qualifyingAt=0, eventFrameMs=0;
  std::uint32_t poseAt=0, poseFrameMs=0, frames=0;
  std::uint32_t batteryMv=0, vbusMv=0;
  std::uint8_t brightness=0;
};
}
