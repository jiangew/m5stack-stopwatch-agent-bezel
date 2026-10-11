#include <cassert>
#include <cmath>
#include <cstdint>
#include <string>
#include <vector>

#include "RobotHomeUi.h"

struct Surface {
  struct Text { std::string value; int x; int y; };
  struct Jpeg {
    const std::uint8_t* bytes; std::uint32_t size; int x; int y;
    int maxWidth; int maxHeight;
    float scaleX; float scaleY;
  };
  std::vector<Text> texts;
  std::vector<Jpeg> jpegs;
  void loadFont(const std::uint8_t*) {}
  void unloadFont() {}
  void setTextDatum(textdatum_t) {}
  void setTextSize(float) {}
  void setTextColor(int) {}
  int textWidth(const char* value) { return static_cast<int>(std::string(value).size()) * 10; }
  void drawString(const char* value, int x, int y) { texts.push_back({value, x, y}); }
  void fillScreen(int) {}
  void fillRect(int x, int y, int width, int height, int) {
    assert(x >= 0 && y >= 0 && x + width <= 466 && y + height <= 466);
  }
  void fillSmoothRoundRect(int x, int y, int width, int height, int, int) {
    fillRect(x, y, width, height, 0);
  }
  void drawCircle(int, int, int, int) {}
  bool drawJpg(const std::uint8_t* bytes, std::uint32_t size, int x, int y,
               int maxWidth, int maxHeight, int, int, float scaleX, float scaleY) {
    jpegs.push_back({bytes, size, x, y, maxWidth, maxHeight, scaleX, scaleY});
    return true;
  }
};

int main() {
  std::vector<const std::uint8_t*> bytes;
  std::size_t totalBytes = 0;
  for (auto character : {robot_home::Character::Bumblebee,
                         robot_home::Character::Optimus,
                         robot_home::Character::Megatron,
                         robot_home::Character::Starscream}) {
    const auto asset = robot_home::character_art::assetFor(character);
    assert(asset.bytes != nullptr);
    assert(asset.size > 0);
    assert(asset.size < 50 * 1024);
    for (const auto* existing : bytes) assert(existing != asset.bytes);
    bytes.push_back(asset.bytes);
    totalBytes += asset.size;
    Surface surface;
    robot_home::State state;
    state.character = character;
    robot_home::render(surface, state);
    assert(surface.jpegs.size() == 1);
    assert(surface.jpegs[0].bytes == asset.bytes);
    assert(surface.jpegs[0].size == asset.size);
    // Exact visible-rim alignment is checked on decoded native pixels by
    // robot_home_spacing_test.rb; JPEG padding differs by character.
    assert(std::fabs(surface.jpegs[0].x + 150 * surface.jpegs[0].scaleX - 233) < 4);
    assert(std::fabs(surface.jpegs[0].y + 150 * surface.jpegs[0].scaleY - 232) < 7);
    assert(surface.jpegs[0].maxWidth == 0);
    assert(surface.jpegs[0].maxHeight == 0);
  }
  assert(totalBytes < 140 * 1024);

  Surface start;
  robot_home::State transition;
  transition.character = robot_home::Character::Optimus;
  transition.transitionProgress = 0.0f;
  robot_home::render(start, transition);
  Surface end;
  transition.transitionProgress = 1.0f;
  robot_home::render(end, transition);
  assert(start.jpegs[0].scaleX < end.jpegs[0].scaleX);
  assert(start.jpegs[0].scaleY == start.jpegs[0].scaleX);
  assert(std::fabs(end.jpegs[0].scaleX - 1.18f) < 0.001f);

  Surface idle;
  robot_home::State reaction;
  reaction.nowMs = 100;
  robot_home::render(idle, reaction);
  Surface blinking;
  reaction.mood = robot_home::Mood::Blink;
  reaction.reactionElapsedMs = 100;
  robot_home::render(blinking, reaction);
  assert(idle.jpegs[0].bytes != blinking.jpegs[0].bytes);
  assert(idle.jpegs[0].x == blinking.jpegs[0].x);
  assert(idle.jpegs[0].y == blinking.jpegs[0].y);
  assert(idle.jpegs[0].scaleX == blinking.jpegs[0].scaleX);

  // Drive the actual Animation -> State -> render path for every character,
  // boundary and millisecond, including uptime rollover and post-sequence idle.
  for (auto character : {robot_home::Character::Bumblebee,
                         robot_home::Character::Optimus,
                         robot_home::Character::Megatron,
                         robot_home::Character::Starscream}) {
    const auto open = robot_home::character_art::assetFor(character, robot_home::BlinkFrame::Open);
    const auto half = robot_home::character_art::assetFor(character, robot_home::BlinkFrame::Half);
    const auto closed = robot_home::character_art::assetFor(character, robot_home::BlinkFrame::Closed);
    assert(open.bytes != half.bytes && half.bytes != closed.bytes && open.bytes != closed.bytes);
    for (std::uint32_t start : {123u, 0xfffffff0u}) {
      robot_home::Animation animation;
      assert(animation.blink(start));
      for (std::uint32_t ms = 0; ms <= 1800; ++ms) {
        const auto phase = ms % 480;
        const auto expected = ms >= 1320 || phase >= 360 ? open
            : phase < 70 || phase >= 230 ? half : closed;
        robot_home::State state;
        state.character = character;
        state.nowMs = start + ms;
        state.mood = animation.mood(state.nowMs);
        state.reactionElapsedMs = animation.elapsed(state.nowMs);
        if (ms < 1320) assert(!animation.blink(state.nowMs));
        Surface surface;
        robot_home::render(surface, state);
        assert(surface.jpegs.size() == 1);
        assert(surface.jpegs[0].bytes == expected.bytes);
        assert(surface.jpegs[0].size == expected.size);
      }
    }
  }

  for (bool charging : {false, true})
    for (int battery : {-1, 0, 9, 78, 100})
      for (auto character : {robot_home::Character::Bumblebee,
                             robot_home::Character::Optimus,
                             robot_home::Character::Megatron,
                             robot_home::Character::Starscream}) {
        Surface surface;
        robot_home::State state;
        state.batteryPercent = battery;
        state.charging = charging;
        state.character = character;
        robot_home::render(surface, state);
        bool foundBattery = false;
        bool foundConnection = false;
        for (const auto& text : surface.texts) {
          if (text.value.find('%') != std::string::npos) {
            foundBattery = true;
            assert(text.y == 420);
            const int left = text.x - 30;
            const int right = text.x + surface.textWidth(text.value.c_str());
            assert((left + right) / 2 == 233);
          }
          if (text.value == "CONNECTED" || text.value == "OFFLINE") {
            foundConnection = true;
            assert(text.y == 44);
          }
        }
        assert(foundBattery);
        assert(foundConnection);
      }

  // Oversized/shifted animation frames must not collide with the status or
  // battery. The ring-free JPEG has >= 8px black margin on each edge.
  // Sample the full blink and the complete transition range.
  for (auto character : {robot_home::Character::Bumblebee,
                         robot_home::Character::Optimus,
                         robot_home::Character::Megatron,
                         robot_home::Character::Starscream})
    for (int progress = 0; progress <= 10; ++progress)
      for (unsigned ms = 0; ms <= robot_home::kBlinkDurationMs; ++ms) {
        Surface surface;
        robot_home::State state;
        state.character = character;
        state.mood = robot_home::Mood::Blink;
        state.reactionElapsedMs = ms;
        state.transitionProgress = progress / 10.0f;
        robot_home::render(surface, state);
        const auto& frame = surface.jpegs[0];
        assert(frame.x >= 0 && frame.y >= 0);
        assert(frame.x + 300 * frame.scaleX < 466);
        assert(frame.y + 300 * frame.scaleY < 466);
        assert(frame.y + 8 * frame.scaleY > 53); // status bottom
        assert(frame.y + 292 * frame.scaleY < 411); // battery top
        const float cx = frame.x + 150 * frame.scaleX;
        const float cy = frame.y + 150 * frame.scaleY;
        const float dx = cx - 233;
        const float dy = cy - 233;
        assert(std::sqrt(dx * dx + dy * dy) + 150 * frame.scaleX < 233);
      }
}
