// SPDX-License-Identifier: MIT
#pragma once

#include "TouchGesture.h"
#include "WorkspaceMode.h"

namespace workspace_navigation {

enum class Family : std::uint8_t { Native, Dedicated };
enum class Workspace : std::uint8_t { Super, Hermes, Home };

struct Event {
  Family family = Family::Native;
  Workspace workspace = Workspace::Super;
  touch_gesture::Direction direction = touch_gesture::Direction::None;
  bool pressed = false;
};

class Gesture {
 public:
  bool begin(workspace_mode::Mode mode, touch_gesture::Direction direction,
             Event& event) {
    if (active_ || direction == touch_gesture::Direction::None) return false;
    if (mode == workspace_mode::Mode::Home && direction != touch_gesture::Direction::Left) return false;
    origin_ = {mode != workspace_mode::Mode::Codex ? Family::Dedicated : Family::Native,
               mode == workspace_mode::Mode::Home ? Workspace::Home :
               workspace_mode::isHermes(mode) ? Workspace::Hermes : Workspace::Super,
               direction, true};
    active_ = true;
    event = origin_;
    return true;
  }

  bool end(Event& event) {
    if (!active_) return false;
    event = origin_;
    event.pressed = false;
    active_ = false;
    return true;
  }

  void reset() { active_ = false; }

 private:
  bool active_ = false;
  Event origin_;
};

inline const char* directionName(touch_gesture::Direction direction) {
  switch (direction) {
    case touch_gesture::Direction::Up: return "up";
    case touch_gesture::Direction::Down: return "down";
    case touch_gesture::Direction::Left: return "left";
    case touch_gesture::Direction::Right: return "right";
    case touch_gesture::Direction::None: return "none";
  }
  return "none";
}

inline void write(JsonObject message, const Event& event) {
  message["method"] = event.family == Family::Native ? "v.oai.rad" :
                      "host.workspace_navigation";
  JsonObject params = message.createNestedObject("params");
  if (event.family == Family::Native) {
    params["a"] = touch_gesture::normalizedAngle(event.direction);
    params["d"] = event.pressed ? 1.0f : 0.0f;
  } else {
    params["workspace"] = event.workspace == Workspace::Home ? "home" : event.workspace == Workspace::Super ? "super" : "hermes";
    params["direction"] = directionName(event.direction);
    params["phase"] = event.pressed ? "press" : "release";
  }
}

}  // namespace workspace_navigation
