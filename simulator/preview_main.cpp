// Native, headless, pixel-identical workspace renderer.
#include <M5GFX.h>

#include <cstdint>
#include <cstring>
#include <cstdio>
#include <cstdlib>
#include <string>
#include <vector>

#include "DashboardUi.h"
#include "SuperWorkspaceUi.h"
#include "RobotHomeUi.h"
#include "RobotHomePortraitCanvas.h"

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
  const bool deepseek = std::strncmp(scenario, "deepseek", 8) == 0;
  if (deepseek) state.profile = super_workspace::Profile::Deepseek;
  const char* suffix = scenario + (deepseek ? 8 : (hermes ? 6 : 5));
  if (std::strcmp(suffix, "-idle") == 0) state.hermesPresentation = super_workspace::HermesPresentation::Idle;
  if (std::strcmp(suffix, "-opening") == 0) state.hermesPresentation = super_workspace::HermesPresentation::Opening;
  if (std::strcmp(suffix, "-error") == 0) state.hermesPresentation = super_workspace::HermesPresentation::Error;
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
  for (const char* base : {"home","home-bumblebee","home-bumblebeefullbody",
                           "home-optimus","home-jazz","home-hotrod","home-wheeljack","home-hound",
                           "home-ironhide","home-ratchet","home-megatron","home-starscream",
                           "home-soundwave","home-shockwave","home-thundercracker","home-skywarp",
                           "home-blitzwing","home-astrotrain"})
    for (const char* suffix : {"","-press","-skill","-transition"})
      if (std::string(scenario)==std::string(base)+suffix) return true;
  for (const char* name : {"home-offline","home-charging","home-unknown","home-low","home-power-hold"})
    if (std::strcmp(scenario,name)==0) return true;
  const bool hermes = std::strncmp(scenario, "hermes", 6) == 0;
  const bool super = std::strncmp(scenario, "super", 5) == 0;
  const bool deepseek = std::strncmp(scenario, "deepseek", 8) == 0;
  const bool codex = std::strncmp(scenario, "codex", 5) == 0;
  if (hermes || super || deepseek || codex) {
    const char* suffix = scenario + (deepseek ? 8 : (hermes ? 6 : 5));
    if (std::strcmp(suffix, "-idle") == 0 ||
        std::strcmp(suffix, "-opening") == 0 ||
        std::strcmp(suffix, "-error") == 0) return true;
    // Codex's active screen remains the existing live/dashboard scenarios.
    if (codex) return false;
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

// Render a sequence in one process, exercising actual cached firmware pixels.
bool writeHomeSequence(const char* directory) {
  robot_home::PortraitCanvas<lgfx::LGFX_Sprite> frame;
  frame.setColorDepth(16);
  if(!frame.createSprite(466,466))return false;
  frame.setTextWrap(false);
  const char* names[]={"bumblebee","bumblebeefullbody","optimus","jazz","hotrod","wheeljack","hound","ironhide","ratchet","megatron","starscream","soundwave","shockwave","thundercracker","skywarp","blitzwing","astrotrain"};
  for(int hero=0;hero<robot_home::kCharacterCount;++hero)for(int i=0;i<54;++i) {
    robot_home::State state;state.character=static_cast<robot_home::Character>(hero);
    state.connected=true;state.batteryPercent=82;
    frame.preparePortraits(state.character);
    if(i>=12&&i<15) {state.mood=robot_home::Mood::Press;state.reactionElapsedMs=(i-12)*1000/30;}
    if(i>=15&&i<33) {state.mood=robot_home::Mood::Skill;state.reactionElapsedMs=(i-15)*1000/30;}
    robot_home::render(frame,state);
    char path[1024];std::snprintf(path,sizeof(path),"%s/%s-%03d.ppm",directory,names[hero],i);
    if(!writePpm(frame,path))return false;
  }
  return true;
}

// Synthetic sensor playback through the actual detector and cached renderer.
// This is a design preview, not hardware latency or false-trigger evidence.
bool writeImuSequence(const char* directory) {
  robot_home::PortraitCanvas<lgfx::LGFX_Sprite> frame;
  frame.setColorDepth(16);
  if(!frame.createSprite(466,466))return false;
  robot_home::imu::Detector detector;
  robot_home::Animation animation;
  unsigned index=0;
  for(unsigned ms=0;ms<8000;ms+=20) {
    robot_home::imu::Sample sample;
    if(ms>=2000&&ms<2160)sample.az=1.16f;
    if(ms>=2160&&ms<4800) {
      const float roll=std::sin((ms-2160)/2640.0f*6.2831853f)*.6f;
      sample.ay=std::sin(roll);sample.az=std::cos(roll);sample.gx=30;
    }
    const auto result=detector.update(sample,ms);
    if(result.event==robot_home::imu::Event::Pickup)animation.cancel();
    if(result.event==robot_home::imu::Event::Settled)animation.cancel();
    if(ms%40)continue;
    robot_home::State state;state.connected=true;state.batteryPercent=82;
    state.character=robot_home::Character::BumblebeeFullbody;
    frame.preparePortraits(state.character);
    state.imuPose=result.pose;state.mood=animation.mood(ms);
    state.reactionElapsedMs=animation.elapsed(ms);
    robot_home::render(frame,state);
    char path[1024];std::snprintf(path,sizeof(path),"%s/imu-%03u.ppm",directory,index++);
    if(!writePpm(frame,path))return false;
  }
  return true;
}

}  // namespace

int main(int argc, char** argv) {
  if(argc==3&&std::strcmp(argv[1],"--imu-sequence")==0)return writeImuSequence(argv[2])?0:1;
  if(argc==3&&std::strcmp(argv[1],"--home-sequence")==0)return writeHomeSequence(argv[2])?0:1;
  const char* outputPath = argc > 1 ? argv[1] : "dashboard-preview.ppm";
  const char* scenario = argc > 2 ? argv[2] : "live";
  if (!validScenario(scenario)) {
    std::fprintf(stderr,
                 "Unknown scenario '%s' (use live, ble, live-stale, offline, "
                 "power-hold, power-off; codex/super/hermes/deepseek accept "
                 "-idle/-opening/-error; super/hermes/deepseek also accept "
                 "-active-up/-right/-down/-left, -offline, -charging, "
                 "-power-hold, -unknown-battery, -colors, -battery-0/-9/-100; "
                 "live also accepts -charging, -unknown-battery, -battery-0/-9/-100)\n",
                 scenario);
    return 2;
  }
  robot_home::PortraitCanvas<lgfx::LGFX_Sprite> framebuffer;
  framebuffer.setColorDepth(16);
  if (framebuffer.createSprite(dashboard::kWidth, dashboard::kHeight) == nullptr) {
    std::fprintf(stderr, "Could not allocate preview framebuffer\n");
    return 1;
  }
  framebuffer.setTextWrap(false);
  if (std::strncmp(scenario,"home",4)==0) {
    robot_home::State state;state.batteryPercent=82;state.connected=true;
    if(std::strncmp(scenario,"home-bumblebeefullbody",22)==0)state.character=robot_home::Character::BumblebeeFullbody;
    if(std::strncmp(scenario,"home-optimus",12)==0)state.character=robot_home::Character::Optimus;
    if(std::strncmp(scenario,"home-jazz",9)==0)state.character=robot_home::Character::Jazz;
    if(std::strncmp(scenario,"home-hotrod",11)==0)state.character=robot_home::Character::Hotrod;
    if(std::strncmp(scenario,"home-wheeljack",14)==0)state.character=robot_home::Character::Wheeljack;
    if(std::strncmp(scenario,"home-hound",10)==0)state.character=robot_home::Character::Hound;
    if(std::strncmp(scenario,"home-ironhide",13)==0)state.character=robot_home::Character::Ironhide;
    if(std::strncmp(scenario,"home-ratchet",12)==0)state.character=robot_home::Character::Ratchet;
    if(std::strncmp(scenario,"home-megatron",13)==0)state.character=robot_home::Character::Megatron;
    if(std::strncmp(scenario,"home-starscream",15)==0)state.character=robot_home::Character::Starscream;
    if(std::strncmp(scenario,"home-soundwave",14)==0)state.character=robot_home::Character::Soundwave;
    if(std::strncmp(scenario,"home-shockwave",14)==0)state.character=robot_home::Character::Shockwave;
    if(std::strncmp(scenario,"home-thundercracker",19)==0)state.character=robot_home::Character::Thundercracker;
    if(std::strncmp(scenario,"home-skywarp",12)==0)state.character=robot_home::Character::Skywarp;
    if(std::strncmp(scenario,"home-blitzwing",14)==0)state.character=robot_home::Character::Blitzwing;
    if(std::strncmp(scenario,"home-astrotrain",15)==0)state.character=robot_home::Character::Astrotrain;
    if(std::strstr(scenario,"-transition")!=nullptr)state.transitionProgress=0.5f;
    const std::uint32_t elapsed = argc > 3 ? std::strtoul(argv[3], nullptr, 10) : 100;
    robot_home::Animation animation;
    constexpr std::uint32_t start=0xfffffff0u;
    if(std::strstr(scenario,"-press")!=nullptr) animation.press(start);
    if(std::strstr(scenario,"-skill")!=nullptr) {animation.press(start);animation.release(start);}
    state.nowMs=start+elapsed;
    state.mood=animation.mood(state.nowMs);
    state.reactionElapsedMs=animation.elapsed(state.nowMs);
    framebuffer.preparePortraits(state.character);
    if(std::strcmp(scenario,"home-offline")==0)state.connected=false;
    if(std::strcmp(scenario,"home-charging")==0)state.charging=true;
    if(std::strcmp(scenario,"home-unknown")==0)state.batteryPercent=-1;
    if(std::strcmp(scenario,"home-low")==0)state.batteryPercent=9;
    if(std::strcmp(scenario,"home-power-hold")==0){state.powerOverlay=super_workspace::PowerOverlay::HoldToPowerOff;state.powerHoldProgress=.5f;}
    robot_home::render(framebuffer,state);
  } else if (std::strncmp(scenario, "super", 5) == 0 ||
      std::strncmp(scenario, "hermes", 6) == 0 ||
      std::strncmp(scenario, "deepseek", 8) == 0) {
    super_workspace::render(framebuffer, superPreviewState(scenario));
  } else {
    // Codex idle/opening/error intentionally use the unchanged live fixture:
    // launch state changes input policy, never the installed dashboard UI.
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
