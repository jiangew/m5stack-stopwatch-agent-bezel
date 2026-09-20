// SPDX-License-Identifier: MIT
#pragma once

#include <algorithm>
#include <cstdio>

#include "RobotHomeCharacters.h"
#include "SuperWorkspaceUi.h"

namespace robot_home {

struct State {
  Mood mood = Mood::Idle;
  Character character = Character::Bumblebee;
  std::uint32_t nowMs = 0;
  float transitionProgress = 1.0f;
  int batteryPercent = -1;
  bool charging = false;
  bool connected = false;
  super_workspace::PowerOverlay powerOverlay =
      super_workspace::PowerOverlay::None;
  float powerHoldProgress = 0;
};

template <class Surface>
void render(Surface& surface, const State& state) {
  constexpr std::uint16_t kMuted = 0x8C92;
  constexpr std::uint16_t kYellow = 0xFE67;

  surface.fillScreen(0);
  renderCharacter(surface, state.character, state.mood, state.nowMs,
                  state.transitionProgress);

  surface.loadFont(dashboard::font_data::kSpaceMono18Vlw);
  super_workspace::drawText(surface,
                            state.connected ? "CONNECTED" : "OFFLINE", 233,
                            64, middle_center,
                            state.connected ? 0x8ED6 : kMuted);
  char battery[8];
  if (state.batteryPercent < 0)
    std::snprintf(battery, sizeof battery, "--%%");
  else
    std::snprintf(battery, sizeof battery, "%d%%",
                  std::min(100, state.batteryPercent));
  const int width = surface.textWidth(battery);
  const int left = 233 - (30 + width) / 2;
  const int color = state.batteryPercent >= 0 && state.batteryPercent <= 15
                        ? 0xFB29
                        : kMuted;
  surface.fillSmoothRoundRect(left, 389, 20, 12, 2, color);
  surface.fillRect(left + 20, 393, 2, 4, color);
  surface.fillRect(left + 2, 391, 16, 8, 0);
  if (state.charging)
    surface.fillRect(left + 9, 390, 3, 10, kYellow);
  else if (state.batteryPercent > 0)
    surface.fillRect(
        left + 3, 392,
        std::max(1, 14 * std::min(100, state.batteryPercent) / 100), 6,
        color);
  super_workspace::drawText(surface, battery, left + 30, 395, middle_left,
                            color);
  surface.unloadFont();

  if (state.powerOverlay != super_workspace::PowerOverlay::None) {
    super_workspace::State overlay;
    overlay.powerOverlay = state.powerOverlay;
    overlay.powerHoldProgress = state.powerHoldProgress;
    super_workspace::drawPowerOverlay(surface, overlay);
  }
}

}  // namespace robot_home
