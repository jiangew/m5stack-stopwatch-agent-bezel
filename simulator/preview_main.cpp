// Native, headless, pixel-identical workspace renderer.
#include <M5GFX.h>

#include <cstdint>
#include <cstring>
#include <cstdio>
#include <string>
#include <vector>

#include "DashboardUi.h"
#include "SuperWorkspaceUi.h"

namespace {

dashboard::State previewState(const char* scenario) {
  dashboard::State state;
  state.linkHealth = dashboard::LinkHealth::CodexLive;
  state.batteryPercent = 82;
  state.quotaAvailable = true;
  state.remainingPercent = 82.0f;
  state.resetInSeconds = 4 * 86400 + 3 * 3600;
  state.threads = {{
      {0xE9EEF5, 0.90f, false},  // idle
      {0x3794FF, 1.00f, true},   // thinking
      {0x2DDD72, 1.00f, false},  // complete
      {0xFFB020, 1.00f, false},  // requires input
      {0xFF4D5E, 1.00f, false},  // error
      {0x000000, 0.00f, false},  // unassigned
  }};

  if (std::strcmp(scenario, "live-battery-0") == 0) {
    state.batteryPercent = 0;
  } else if (std::strcmp(scenario, "live-battery-9") == 0) {
    state.batteryPercent = 9;
  } else if (std::strcmp(scenario, "live-battery-100") == 0) {
    state.batteryPercent = 100;
  } else if (std::strcmp(scenario, "live-unknown-battery") == 0) {
    state.batteryPercent = -1;
  } else if (std::strcmp(scenario, "live-charging") == 0) {
    state.charging = true;
    state.docked = true;
  } else if (std::strcmp(scenario, "ble") == 0) {
    state.linkHealth = dashboard::LinkHealth::BleOnly;
    state.batteryPercent = 61;
    state.charging = true;
    state.docked = true;
  } else if (std::strcmp(scenario, "live-stale") == 0) {
    state.linkHealth = dashboard::LinkHealth::CodexLive;
    state.quotaStale = true;
    state.batteryPercent = 17;
    state.remainingPercent = 19.0f;
    state.resetInSeconds = 17 * 3600 + 22 * 60;
  } else if (std::strcmp(scenario, "offline") == 0) {
    state.linkHealth = dashboard::LinkHealth::Offline;
    state.batteryPercent = 44;
    state.quotaAvailable = false;
    state.remainingPercent = 0.0f;
    state.resetInSeconds = 0;
  } else if (std::strcmp(scenario, "power-hold") == 0) {
    state.powerOverlay = dashboard::PowerOverlay::HoldToPowerOff;
    state.powerHoldProgress = 0.56f;
  } else if (std::strcmp(scenario, "power-off") == 0) {
    state.linkHealth = dashboard::LinkHealth::Offline;
    state.powerOverlay = dashboard::PowerOverlay::PoweringOff;
  }
  return state;
}

super_workspace::State superPreviewState(const char* scenario) {
  super_workspace::State state;
  state.batteryPercent = 78;
  state.connected = true;

  const bool hermes = std::strncmp(scenario, "hermes", 6) == 0;
  if (hermes) state.profile = super_workspace::Profile::Hermes;
  const char* suffix = scenario + (hermes ? 6 : 5);
  if (hermes) {
    if (std::strcmp(suffix, "-idle") == 0) state.hermesPresentation = super_workspace::HermesPresentation::Idle;
    if (std::strcmp(suffix, "-opening") == 0) state.hermesPresentation = super_workspace::HermesPresentation::Opening;
    if (std::strcmp(suffix, "-error") == 0) state.hermesPresentation = super_workspace::HermesPresentation::Error;
  }
  if (std::strcmp(suffix, "-battery-0") == 0) {
    state.batteryPercent = 0;
  } else if (std::strcmp(suffix, "-battery-9") == 0) {
    state.batteryPercent = 9;
  } else if (std::strcmp(suffix, "-battery-100") == 0) {
    state.batteryPercent = 100;
  } else if (std::strcmp(suffix, "-active-right") == 0) {
    state.swipeDirection = touch_gesture::Direction::Right;
  } else if (std::strcmp(suffix, "-active-up") == 0) {
    state.swipeDirection = touch_gesture::Direction::Up;
  } else if (std::strcmp(suffix, "-active-down") == 0) {
    state.swipeDirection = touch_gesture::Direction::Down;
  } else if (std::strcmp(suffix, "-active-left") == 0) {
    state.swipeDirection = touch_gesture::Direction::Left;
  } else if (std::strcmp(suffix, "-offline") == 0) {
    state.connected = false;
    state.batteryPercent = 18;
  } else if (std::strcmp(suffix, "-charging") == 0) {
    state.charging = true;
  } else if (std::strcmp(suffix, "-power-hold") == 0) {
    state.powerOverlay = super_workspace::PowerOverlay::HoldToPowerOff;
    state.powerHoldProgress = 0.56f;
  } else if (std::strcmp(suffix, "-unknown-battery") == 0) {
    state.batteryPercent = -1;
  } else if (std::strcmp(suffix, "-colors") == 0) {
    workspace_palette::Palette palette;
    unsigned seed = 7;
    palette.acceptSwipe(0, [&] { seed = seed * 1664525u + 1013904223u; return seed; });
    state.borderColors = palette.colors();
  }
  return state;
}

bool validScenario(const char* scenario) {
  const bool hermes = std::strncmp(scenario, "hermes", 6) == 0;
  const bool super = std::strncmp(scenario, "super", 5) == 0;
  if (hermes || super) {
    const char* suffix = scenario + (hermes ? 6 : 5);
    if (hermes && (std::strcmp(suffix, "-idle") == 0 ||
                   std::strcmp(suffix, "-opening") == 0 ||
                   std::strcmp(suffix, "-error") == 0)) return true;
    for (const auto* known : {"", "-active-up", "-active-right", "-active-down",
                              "-active-left", "-offline", "-charging",
                              "-power-hold", "-unknown-battery", "-colors",
                              "-battery-0", "-battery-9", "-battery-100"})
      if (std::strcmp(suffix, known) == 0) return true;
    return false;
  }
  return std::strcmp(scenario, "live") == 0 ||
         std::strcmp(scenario, "live-battery-0") == 0 ||
         std::strcmp(scenario, "live-battery-9") == 0 ||
         std::strcmp(scenario, "live-battery-100") == 0 ||
         std::strcmp(scenario, "live-unknown-battery") == 0 ||
         std::strcmp(scenario, "live-charging") == 0 ||
         std::strcmp(scenario, "ble") == 0 ||
         std::strcmp(scenario, "live-stale") == 0 ||
         std::strcmp(scenario, "offline") == 0 ||
         std::strcmp(scenario, "super") == 0 ||
         std::strcmp(scenario, "super-active-right") == 0 ||
         std::strcmp(scenario, "super-offline") == 0 ||
         std::strcmp(scenario, "super-charging") == 0 ||
         std::strcmp(scenario, "super-power-hold") == 0 ||
         std::strcmp(scenario, "power-hold") == 0 ||
         std::strcmp(scenario, "power-off") == 0;
}

bool writePpm(lgfx::LGFX_Sprite& sprite, const char* path) {
  std::FILE* output = std::fopen(path, "wb");
  if (output == nullptr) return false;
  std::fprintf(output, "P6\n%d %d\n255\n", dashboard::kWidth,
               dashboard::kHeight);
  std::vector<lgfx::bgr888_t> pixels(dashboard::kWidth * dashboard::kHeight);
  sprite.readRectRGB(0, 0, dashboard::kWidth, dashboard::kHeight, pixels.data());
  for (const auto& pixel : pixels) {
    const std::uint8_t rgb[3] = {pixel.R8(), pixel.G8(), pixel.B8()};
    std::fwrite(rgb, 1, sizeof(rgb), output);
  }
  return std::fclose(output) == 0;
}

}  // namespace

int main(int argc, char** argv) {
  const char* outputPath = argc > 1 ? argv[1] : "dashboard-preview.ppm";
  const char* scenario = argc > 2 ? argv[2] : "live";
  if (!validScenario(scenario)) {
    std::fprintf(stderr,
                 "Unknown scenario '%s' (use live, ble, live-stale, offline, "
                 "power-hold, power-off; super/hermes with optional "
                 "-active-up/-right/-down/-left, -offline, -charging, "
                 "-power-hold, -unknown-battery, -colors, -battery-0/-9/-100; "
                 "live also accepts -charging, -unknown-battery, -battery-0/-9/-100)\n",
                 scenario);
    return 2;
  }
  lgfx::LGFX_Sprite framebuffer;
  framebuffer.setColorDepth(16);
  if (framebuffer.createSprite(dashboard::kWidth, dashboard::kHeight) == nullptr) {
    std::fprintf(stderr, "Could not allocate preview framebuffer\n");
    return 1;
  }
  framebuffer.setTextWrap(false);
  if (std::strncmp(scenario, "super", 5) == 0 ||
      std::strncmp(scenario, "hermes", 6) == 0) {
    super_workspace::render(framebuffer, superPreviewState(scenario));
  } else {
    dashboard::render(framebuffer, previewState(scenario));
  }
  if (!writePpm(framebuffer, outputPath)) {
    std::fprintf(stderr, "Could not write %s\n", outputPath);
    return 1;
  }
  std::printf("Rendered %s [%s] (%d x %d, RGB565)\n", outputPath, scenario,
              dashboard::kWidth, dashboard::kHeight);
  return 0;
}
