// SPDX-License-Identifier: MIT
#pragma once

#include <cstdint>

#include "WorkspaceMode.h"

namespace workspace_input {

// Directional workspaces defer activity until a swipe or power hold is known.
constexpr bool touchDownWakes(workspace_mode::Mode mode) {
  return mode == workspace_mode::Mode::Codex;
}

enum class Control : std::uint8_t {
  SwipeUp,
  SwipeRight,
  SwipeDown,
  SwipeLeft,
  Agent,
  Send,
  CenterPowerHold,
  LeftPhysicalButton,
  RightPhysicalButton,
  RedPowerButton,
};

inline bool allowed(workspace_mode::Mode mode, Control control) {
  if (mode == workspace_mode::Mode::Codex) return true;
  if (workspace_mode::awaitingLaunch(mode)) {
    return control == Control::SwipeLeft ||
           control == Control::CenterPowerHold || control == Control::RedPowerButton;
  }
  switch (control) {
    case Control::SwipeUp:
    case Control::SwipeRight:
    case Control::SwipeDown:
    case Control::SwipeLeft:
    case Control::CenterPowerHold:
    case Control::RedPowerButton:
      return true;
    case Control::Agent:
    case Control::Send:
    case Control::LeftPhysicalButton:
    case Control::RightPhysicalButton:
      return false;
  }
  return false;
}

}  // namespace workspace_input
