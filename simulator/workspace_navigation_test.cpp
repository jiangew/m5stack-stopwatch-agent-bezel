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
  {
    Gesture gesture; Event press{}, release{};
    assert(gesture.begin(Mode::Deepseek, Direction::Left, press));
    assert(json(press) == "{\"method\":\"host.workspace_navigation\",\"params\":{\"workspace\":\"deepseek\",\"direction\":\"left\",\"phase\":\"press\"}}");
    assert(gesture.end(release));
    assert(release.workspace == press.workspace && !release.pressed);
    assert(json(release).find("v.oai.rad") == std::string::npos);
  }
  for(auto direction:{Direction::Up,Direction::Down,Direction::Right}){
    Gesture home;Event event{};assert(!home.begin(Mode::Home,direction,event));
  }
  {Gesture home;Event event{};assert(home.begin(Mode::Home,Direction::Left,event));
   assert(json(event)=="{\"method\":\"host.workspace_navigation\",\"params\":{\"workspace\":\"home\",\"direction\":\"left\",\"phase\":\"press\"}}");}
  for (auto mode : {Mode::Codex, Mode::Deepseek, Mode::Super, Mode::Hermes}) {
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
        assert(down.find(mode == Mode::Deepseek ? "\"workspace\":\"deepseek\"" : mode == Mode::Super ? "\"workspace\":\"super\"" :
                         "\"workspace\":\"hermes\"") != std::string::npos);
      }
      assert(gesture.begin(mode, direction, press));
      gesture.reset();
      assert(!gesture.end(release));
      assert(gesture.begin(Mode::Codex, direction, press));
      assert(press.family == Family::Native);
    }
  }
  for (auto mode : {Mode::CodexIdle, Mode::CodexOpening, Mode::CodexError,
       Mode::DeepseekIdle, Mode::DeepseekOpening, Mode::DeepseekError,
       Mode::SuperIdle, Mode::SuperOpening, Mode::SuperError,
       Mode::HermesIdle, Mode::HermesOpening, Mode::HermesError}) {
    Gesture gesture; Event event{}, release{};
    for (auto direction : {Direction::Up, Direction::Down, Direction::Right})
      assert(!gesture.begin(mode, direction, event));
    assert(gesture.begin(mode, Direction::Left, event));
    const char* profile = workspace_mode::isCodex(mode) ? "codex" :
        workspace_mode::isDeepseek(mode) ? "deepseek" :
        workspace_mode::isSuper(mode) ? "super" : "hermes";
    assert(json(event) == std::string("{\"method\":\"host.workspace_navigation\",\"params\":{\"workspace\":\"") + profile + "\",\"direction\":\"left\",\"phase\":\"press\"}}");
    assert(!gesture.begin(Mode::Codex, Direction::Right, release));
    assert(gesture.end(release));
    assert(release.family == Family::Dedicated && release.workspace == event.workspace);
    assert(!release.pressed && release.direction == Direction::Left);
    assert(json(release).find("v.oai.rad") == std::string::npos);
    assert(!gesture.end(release));
  }
}
