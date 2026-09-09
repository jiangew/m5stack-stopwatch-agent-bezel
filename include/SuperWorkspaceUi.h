// SPDX-License-Identifier: MIT
#pragma once

#include <M5GFX.h>

#include <algorithm>
#include <array>
#include <cstdint>
#include <cstdio>

#include "SpaceMonoVlw.h"
#include "TouchGesture.h"
#include "WorkspacePalette.h"

namespace super_workspace {

constexpr int kWidth = 466;
constexpr int kHeight = 466;
constexpr int kCenterX = kWidth / 2;

constexpr std::uint16_t kBackground = 0x0041;
constexpr std::uint16_t kCenterFill = 0x0862;
constexpr std::uint16_t kCenterBorder = 0x372F;
constexpr std::uint16_t kPanel = 0x18C8;
constexpr std::uint16_t kText = 0xF7DF;
constexpr std::uint16_t kMuted = 0x8410;
constexpr std::uint16_t kAccent = 0xA2FF;
constexpr std::uint16_t kConnected = kCenterBorder;
constexpr std::uint16_t kWarning = 0xFDA9;
constexpr std::uint16_t kDanger = 0xFAED;

constexpr const char* kTitle = "SUPER";
constexpr int kOutlineWidth = 5;

enum class PowerOverlay : std::uint8_t {
  None,
  HoldToPowerOff,
  PoweringOff,
};

struct Point {
  int x;
  int y;

  constexpr bool operator==(const Point& other) const {
    return x == other.x && y == other.y;
  }
};

struct Rect {
  int left;
  int top;
  int right;
  int bottom;
};

struct DirectionalControl {
  touch_gesture::Direction direction;
  const char* label;
  Point baseStart;
  Point baseEnd;
  Point tip;
  Point innerBaseStart;
  Point innerBaseEnd;
  Point innerTip;
  Point labelAnchor;
  std::uint16_t borderColor;
  std::uint16_t fillColor;
  std::uint16_t activeBorderColor;
  std::uint16_t activeFillColor;
};

constexpr Rect kCenterSquare{143, 143, 322, 322};

static constexpr std::array<DirectionalControl, 4> kDirectionalControls = {{
    {touch_gesture::Direction::Up,
     "PREV",
     {143, 143}, {322, 143}, {233, 26},
     {149, 138}, {316, 138}, {233, 36}, {233, 91},
     0x26DF, 0x0082, 0x673F, 0x0A09},
    {touch_gesture::Direction::Right,
     "TAB",
     {322, 143}, {322, 322}, {440, 233},
     {327, 149}, {327, 316}, {430, 233}, {375, 233},
     0xFCE6, 0x1061, 0xFDCE, 0x4961},
    {touch_gesture::Direction::Down,
     "NEXT",
     {322, 322}, {143, 322}, {233, 440},
     {316, 327}, {149, 327}, {233, 430}, {233, 387},
     0xEA7F, 0x1042, 0xF43F, 0x40C9},
    {touch_gesture::Direction::Left,
     "CYCLE",
     {143, 322}, {143, 143}, {26, 233},
     {138, 316}, {138, 149}, {36, 233}, {90, 233},
     0x53DF, 0x0862, 0x8D1F, 0x1929},
}};

enum class Profile : std::uint8_t { Super, Hermes };
enum class HermesPresentation : std::uint8_t { Active, Idle, Opening, Error };

struct State {
  Profile profile = Profile::Super;
  HermesPresentation hermesPresentation = HermesPresentation::Active;
  workspace_palette::Colors borderColors = workspace_palette::kInitialColors;
  std::int8_t batteryPercent = -1;
  bool charging = false;
  bool connected = false;
  touch_gesture::Direction swipeDirection = touch_gesture::Direction::None;
  PowerOverlay powerOverlay = PowerOverlay::None;
  float powerHoldProgress = 0.0f;
};

template <typename Surface>
void drawText(Surface& surface, const char* text, int x, int y,
              textdatum_t datum, std::uint16_t color) {
  surface.setTextDatum(datum);
  surface.setTextSize(1.0f);
  surface.setTextColor(color);
  surface.drawString(text, x, y);
}

template <typename Surface>
void drawDirectionalControl(Surface& surface,
                            const DirectionalControl& control,
                            bool active, std::uint16_t borderColor,
                            const char* label) {
  const std::uint16_t fillColor =
      active ? control.activeFillColor : control.fillColor;
  surface.fillTriangle(control.baseStart.x, control.baseStart.y,
                       control.baseEnd.x, control.baseEnd.y,
                       control.tip.x, control.tip.y, borderColor);
  surface.fillTriangle(control.innerBaseStart.x, control.innerBaseStart.y,
                       control.innerBaseEnd.x, control.innerBaseEnd.y,
                       control.innerTip.x, control.innerTip.y, fillColor);

  surface.loadFont(dashboard::font_data::kSpaceMono18Vlw);
  drawText(surface, label, control.labelAnchor.x,
           control.labelAnchor.y, middle_center,
           control.borderColor);
  surface.unloadFont();
}

template <typename Surface>
void drawCenterBattery(Surface& surface, const State& state) {
  constexpr int batteryY = 268;
  constexpr int batteryWidth = 31;
  constexpr int batteryHeight = 16;
  const int battery = std::max(
      -1, std::min(100, static_cast<int>(state.batteryPercent)));
  const std::uint16_t color =
      battery < 0 ? kMuted : (battery <= 20 ? kWarning : kText);

  char label[12];
  if (battery < 0) {
    std::snprintf(label, sizeof(label), "--%%");
  } else {
    std::snprintf(label, sizeof(label), "%d%%", battery);
  }
  surface.loadFont(dashboard::font_data::kSpaceMono18Vlw);
  surface.setTextSize(1.0f);
  constexpr int terminalWidth = 3;
  constexpr int gap = 8;
  const int groupWidth = batteryWidth + terminalWidth + gap + surface.textWidth(label);
  const int batteryX = kCenterX - groupWidth / 2;

  surface.fillSmoothRoundRect(batteryX, batteryY, batteryWidth, batteryHeight,
                              3, color);
  surface.fillSmoothRoundRect(batteryX + 2, batteryY + 2, batteryWidth - 4,
                              batteryHeight - 4, 2, kCenterFill);
  surface.fillSmoothRoundRect(batteryX + batteryWidth, batteryY + 4, 3,
                              batteryHeight - 8, 1, color);
  if (battery > 0) {
    const int fillWidth = std::max(2, (batteryWidth - 6) * battery / 100);
    surface.fillSmoothRoundRect(batteryX + 3, batteryY + 3, fillWidth,
                                batteryHeight - 6, 1, color);
  }
  if (state.charging) {
    const int boltX = batteryX + batteryWidth / 2;
    surface.fillTriangle(boltX, batteryY + 1, boltX - 5, batteryY + 8,
                         boltX - 1, batteryY + 8, kText);
    surface.fillTriangle(boltX - 1, batteryY + 7, boltX + 4, batteryY + 7,
                         boltX - 3, batteryY + batteryHeight - 1, kText);
  }

  drawText(surface, label, batteryX + batteryWidth + terminalWidth + gap,
           batteryY + batteryHeight / 2,
           middle_left, color);
  surface.unloadFont();
}

template <typename Surface>
void drawCenterPanel(Surface& surface, const State& state) {
  // Preserve all four triangle bases; no separate square outline.
  surface.fillRect(kCenterSquare.left + 1, kCenterSquare.top + 1,
                   kCenterSquare.right - kCenterSquare.left - 1,
                   kCenterSquare.bottom - kCenterSquare.top - 1,
                   kCenterFill);

  const bool pending = state.profile == Profile::Hermes &&
                       state.hermesPresentation != HermesPresentation::Active;
  surface.loadFont(dashboard::font_data::kSpaceMono46Vlw);
  drawText(surface, state.profile == Profile::Hermes ? "HERMES" : kTitle,
           kCenterX, pending ? 182 : 190, middle_center, kText);
  surface.unloadFont();

  surface.loadFont(dashboard::font_data::kSpaceMono18Vlw);
  if (pending) {
    const char* prompt = state.hermesPresentation == HermesPresentation::Idle
        ? "TAP TO OPEN" : (state.hermesPresentation == HermesPresentation::Opening
        ? "OPENING" : "TAP TO RETRY");
    drawText(surface, prompt, kCenterX, 222, middle_center, kText);
  }
  const char* status = state.connected ? "CONNECTED" : "OFFLINE";
  const std::uint16_t statusColor = state.connected ? kConnected : kDanger;
  drawText(surface, status, kCenterX, pending ? 247 : 239, middle_center, statusColor);
  surface.unloadFont();

  drawCenterBattery(surface, state);
}

template <typename Surface>
void drawPowerOverlay(Surface& surface, const State& state) {
  if (state.powerOverlay == PowerOverlay::None) return;

  const bool confirming = state.powerOverlay == PowerOverlay::HoldToPowerOff;
  const char* heading = confirming ? "KEEP HOLDING" : "POWERING OFF";
  const char* detail = confirming ? "ALERTS PAUSE" : "RED OR USB WAKE";
  const std::uint16_t color = confirming ? kWarning : kDanger;
  constexpr int overlayX = 44;
  constexpr int overlayY = 172;
  constexpr int overlayWidth = 378;
  constexpr int overlayHeight = 128;

  surface.fillSmoothRoundRect(overlayX, overlayY, overlayWidth, overlayHeight,
                              24, kAccent);
  surface.fillSmoothRoundRect(overlayX + 4, overlayY + 4, overlayWidth - 8,
                              overlayHeight - 8, 20, kPanel);
  if (confirming) {
    const float progress = std::max(0.0f, std::min(1.0f,
                                                  state.powerHoldProgress));
    surface.fillSmoothRoundRect(overlayX + 28, overlayY + overlayHeight - 24,
                                overlayWidth - 56, 7, 3, kMuted);
    const int progressWidth =
        static_cast<int>((overlayWidth - 56) * progress);
    if (progressWidth > 0) {
      surface.fillSmoothRoundRect(overlayX + 28,
                                  overlayY + overlayHeight - 24,
                                  progressWidth, 7, 3, color);
    }
  }

  surface.loadFont(dashboard::font_data::kSpaceMono18Vlw);
  drawText(surface, heading, kCenterX, overlayY + 39, middle_center, color);
  drawText(surface, detail, kCenterX, overlayY + 70, middle_center, kText);
  surface.unloadFont();
}

template <typename Surface>
void render(Surface& surface, const State& state) {
  surface.fillScreen(kBackground);
  for (std::size_t i = 0; i < kDirectionalControls.size(); ++i) {
    const auto& control = kDirectionalControls[i];
    const char* label = state.profile == Profile::Hermes &&
                        control.direction == touch_gesture::Direction::Right
                            ? "OPEN" : control.label;
    drawDirectionalControl(surface, control,
                           state.swipeDirection == control.direction,
                           state.borderColors[i], label);
  }
  drawCenterPanel(surface, state);
  drawPowerOverlay(surface, state);
}

}  // namespace super_workspace
