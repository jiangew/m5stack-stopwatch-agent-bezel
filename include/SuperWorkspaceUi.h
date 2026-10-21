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

constexpr std::uint16_t kBackground = 0x0000;
constexpr std::uint16_t kCenterFill = 0x10C4;
constexpr std::uint16_t kCenterBorder = 0x16B6;
constexpr std::uint16_t kPanel = 0x10C4;
constexpr std::uint16_t kText = 0xEF7E;
constexpr std::uint16_t kMuted = 0x7C53;
constexpr std::uint16_t kAccent = 0x16B6;
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
  Point center;
};

// Input ownership still uses WorkspaceCenterTap's original center bounds.
constexpr Rect kCenterSquare{143, 143, 322, 322};
constexpr int kControlRadius = 56;
constexpr int kDialY = 237;
constexpr int kDialRadius = 104;
static constexpr std::array<DirectionalControl, 4> kDirectionalControls = {{
    {touch_gesture::Direction::Up, "PREV", {233, 72}},
    {touch_gesture::Direction::Right, "TAB", {398, 237}},
    {touch_gesture::Direction::Down, "NEXT", {233, 402}},
    {touch_gesture::Direction::Left, "CYCLE", {68, 237}},
}};

enum class Profile : std::uint8_t { Super, Hermes, Deepseek };
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
              textdatum_t datum, std::uint16_t color, float textSize = 1.0f) {
  surface.setTextDatum(datum);
  surface.setTextSize(textSize);
  surface.setTextColor(color);
  surface.drawString(text, x, y);
}

constexpr std::uint16_t shade565(std::uint16_t color, float factor) {
  return (static_cast<unsigned>(((color >> 11) & 31) * factor) << 11)
       | (static_cast<unsigned>(((color >> 5) & 63) * factor) << 5)
       | static_cast<unsigned>((color & 31) * factor);
}

constexpr std::uint16_t controlInk(std::uint16_t color) {
  const int r = ((color >> 11) & 31) * 255 / 31;
  const int g = ((color >> 5) & 63) * 255 / 63;
  const int b = (color & 31) * 255 / 31;
  return (r * 299 + g * 587 + b * 114) / 1000 > 150 ? kBackground : kText;
}

template <typename Surface>
void drawDirectionalControl(Surface& surface,
                            const DirectionalControl& control,
                            bool active, std::uint16_t color,
                            const char* label, bool enabled = true) {
  if (!enabled) color = kMuted;
  if (active) color = shade565(color, 0.72f);
  const int x = control.center.x, y = control.center.y;
  surface.fillSmoothCircle(x, y, kControlRadius, shade565(color, 0.55f));
  surface.fillSmoothCircle(x, y, kControlRadius - 3, color);
  const auto ink = controlInk(color);
  const int arrowY = y - 13;
  Point a{}, b{}, c{};
  switch (control.direction) {
    case touch_gesture::Direction::Up: a={x-6,arrowY+3}; b={x,arrowY-3}; c={x+6,arrowY+3}; break;
    case touch_gesture::Direction::Down: a={x-6,arrowY-3}; b={x,arrowY+3}; c={x+6,arrowY-3}; break;
    case touch_gesture::Direction::Left: a={x+3,arrowY-6}; b={x-3,arrowY}; c={x+3,arrowY+6}; break;
    default: a={x-3,arrowY-6}; b={x+3,arrowY}; c={x-3,arrowY+6}; break;
  }
  surface.drawLine(a.x,a.y,b.x,b.y,ink);
  surface.drawLine(b.x,b.y,c.x,c.y,ink);
  surface.loadFont(dashboard::font_data::kSpaceMono18Vlw);
  drawText(surface, label, x, y + 12, middle_center, ink);
  surface.unloadFont();
}

template <typename Surface>
void drawCenterBattery(Surface& surface, const State& state) {
  constexpr int batteryY = 293;
  constexpr int batteryWidth = 29;
  constexpr int batteryHeight = 15;
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
  // A status ring, never a synthetic quota/progress indicator.
  const auto ring = state.connected ? kConnected : kMuted;
  surface.fillSmoothCircle(kCenterX, kDialY, kDialRadius, ring);
  surface.fillSmoothCircle(kCenterX, kDialY, kDialRadius - 2, kCenterFill);

  const bool pending = state.hermesPresentation != HermesPresentation::Active;
  const char* title = state.profile == Profile::Deepseek ? "DSH"
      : state.profile == Profile::Hermes ? "HERMES" : kTitle;
  // All titles use the same font asset. Measure at the preferred size before
  // shrinking longer names to the 178px interior; never stretch shorter names.
  surface.loadFont(dashboard::font_data::kSpaceMono46Vlw);
  surface.setTextSize(1.0f);
  constexpr int titleWidth = kCenterSquare.right - kCenterSquare.left - 1;
  const int measuredWidth = surface.textWidth(title);
  const float titleSize = measuredWidth > titleWidth
      ? static_cast<float>(titleWidth) / measuredWidth : 1.0f;
  drawText(surface, title, kCenterX, 228,
           middle_center, kText, titleSize);
  surface.unloadFont();

  surface.loadFont(dashboard::font_data::kSpaceMono18Vlw);
  if (pending) {
    const char* prompt = state.hermesPresentation == HermesPresentation::Idle
        ? "TAP TO OPEN" : (state.hermesPresentation == HermesPresentation::Opening
        ? "OPENING" : "TAP TO RETRY");
    drawText(surface, prompt, kCenterX, 270, middle_center, kText);
  }
  const char* status = state.connected ? "CONNECTED" : "OFFLINE";
  const std::uint16_t statusColor = state.connected ? kConnected : kDanger;
  drawText(surface, status, kCenterX, 185, middle_center, statusColor);
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
                            ? "OPEN" : (state.profile == Profile::Deepseek &&
                         control.direction == touch_gesture::Direction::Right
                            ? "VIEW" : control.label);
    drawDirectionalControl(surface, control,
                           state.swipeDirection == control.direction,
                           state.borderColors[i], label,
                           state.hermesPresentation == HermesPresentation::Active ||
                           control.direction == touch_gesture::Direction::Left);
  }
  drawCenterPanel(surface, state);
  drawPowerOverlay(surface, state);
}

}  // namespace super_workspace
