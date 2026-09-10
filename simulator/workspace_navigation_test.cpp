#include <cassert>
#include <string>

#include "WorkspaceNavigation.h"

using workspace_mode::Mode;
using touch_gesture::Direction;
using workspace_navigation::Event;
using workspace_navigation::Family;
using workspace_navigation::Gesture;

static std::string json(const Event& event) {
  StaticJsonDocument<384> doc;
  workspace_navigation::write(doc.to<JsonObject>(), event);
  std::string result;
  serializeJson(doc, result);
  assert(!doc.overflowed());
  return result;
}

int main() {
  for (auto mode : {Mode::Codex, Mode::Super, Mode::Hermes,
                    Mode::HermesIdle, Mode::HermesOpening, Mode::HermesError}) {
    for (auto direction : {Direction::Up, Direction::Down, Direction::Left,
                           Direction::Right}) {
      Gesture gesture;
      Event press{}, release{};
      assert(!gesture.end(release));
      assert(!gesture.begin(mode, Direction::None, press));
      assert(gesture.begin(mode, direction, press));
      const std::string down = json(press);
      assert(!gesture.begin(Mode::Codex, Direction::Right, release));
      assert(gesture.end(release));
      assert(!gesture.end(release));
      assert(release.family == press.family);
      assert(release.direction == press.direction);
      assert(release.workspace == press.workspace);
      assert(!release.pressed);
      const std::string up = json(release);
      if (mode == Mode::Codex) {
        assert(press.family == Family::Native);
        assert(down.find("v.oai.rad") != std::string::npos);
        assert(down.find("host.workspace_navigation") == std::string::npos);
        assert(up.find("\"d\":0") != std::string::npos);
      } else {
        assert(press.family == Family::Dedicated);
        assert(down.find("v.oai.rad") == std::string::npos);
        assert(up.find("v.oai.rad") == std::string::npos);
        assert(down.find("\"phase\":\"press\"") != std::string::npos);
        assert(up.find("\"phase\":\"release\"") != std::string::npos);
        assert(down.find(mode == Mode::Super ? "\"workspace\":\"super\"" :
                         "\"workspace\":\"hermes\"") != std::string::npos);
      }
      assert(gesture.begin(mode, direction, press));
      gesture.reset();
      assert(!gesture.end(release));
      assert(gesture.begin(Mode::Codex, direction, press));
      assert(press.family == Family::Native);
    }
  }
  Gesture gesture;
  Event event{};
  assert(gesture.begin(Mode::HermesIdle, Direction::Up, event));
  assert(json(event) == "{\"method\":\"host.workspace_navigation\",\"params\":{\"workspace\":\"hermes\",\"direction\":\"up\",\"phase\":\"press\"}}");
}
