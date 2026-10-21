#include <cassert>
#include <cmath>
#include <cstring>
#include <type_traits>
#include <utility>
#include <array>
#include <string>
#include <vector>

#include "SuperWorkspaceUi.h"

namespace {

struct RecordingSurface {
  struct TextDraw {
    std::string text; int x; int y; textdatum_t datum;
    const std::uint8_t* font; float size; int width;
  };
  const std::uint8_t* font = nullptr;
  float textSize = 1.0f;
  std::vector<TextDraw> textDraws;
  std::vector<std::array<int, 6>> roundRectangles;
  textdatum_t datum = middle_center;
  bool fontLoaded = false;
  std::vector<std::array<int, 5>> rectangles;
  std::vector<int> triangleColors;
  std::vector<std::string> texts;
  std::vector<std::array<int, 4>> circles;
  void fillSmoothCircle(int x,int y,int r,int c) { circles.push_back({x,y,r,c}); }
  void drawLine(int,int,int,int,int) {}
  void fillScreen(int) {}
  void fillRect(int x, int y, int w, int h, int c) { rectangles.push_back({x,y,w,h,c}); }
  void fillTriangle(int, int, int, int, int, int, int c) { triangleColors.push_back(c); }
  void fillSmoothRoundRect(int x, int y, int w, int h, int r, int c) {
    roundRectangles.push_back({x, y, w, h, r, c});
  }
  void loadFont(const std::uint8_t* value) { font = value; fontLoaded = true; }
  void unloadFont() { font = nullptr; fontLoaded = false; }
  int textWidth(const char* text) {
    assert(fontLoaded);
    // Read the embedded VLW metrics, matching M5GFX's fixed-point advance and
    // final glyph extent instead of pretending large-font glyphs are 11px.
    auto read32 = [](const std::uint8_t* p) -> std::int32_t {
      return (std::uint32_t(p[0]) << 24) | (std::uint32_t(p[1]) << 16)
          | (std::uint32_t(p[2]) << 8) | p[3];
    };
    const int scale = static_cast<int>(65536 * textSize);
    int left = 0, right = 0;
    for (; *text; ++text) {
      const std::uint8_t* glyph = nullptr;
      for (int i = 0; i < read32(font); ++i) {
        const auto* candidate = font + 24 + i * 28;
        if (read32(candidate) == *text) { glyph = candidate; break; }
      }
      if (*text == ' ') {
        const int advance = ((std::max(read32(font + 8), read32(font + 16) + read32(font + 20)) * 2 / 7) * scale) >> 16;
        left += advance;
        right = left;
        continue;
      }
      assert(glyph != nullptr);
      const int offset = (read32(glyph + 20) * scale) >> 16;
      const int advance = (read32(glyph + 12) * scale) >> 16;
      if (left == 0 && right == 0 && offset < 0) left = right = -offset;
      right = left + std::max(advance, ((read32(glyph + 8) * scale) >> 16) + offset);
      left += advance;
    }
    return right;
  }
  void setTextDatum(textdatum_t value) { datum = value; }
  void setTextSize(float value) { textSize = value; }
  void setTextColor(int) {}
  void drawString(const char* text, int x, int y) {
    texts.emplace_back(text);
    textDraws.push_back({text, x, y, datum, font, textSize, textWidth(text)});
  }
};

void testBatteryAndLabelAreCenteredAsOneMeasuredGroup() {
  struct Case { int percent; const char* label; int textWidth; };
  const Case cases[] = {{0, "0%", 22}, {9, "9%", 22}, {78, "78%", 33},
                        {100, "100%", 44}, {-1, "--%", 33}};
  for (auto profile : {super_workspace::Profile::Super, super_workspace::Profile::Hermes, super_workspace::Profile::Deepseek}) {
    for (bool charging : {false, true}) {
      for (const auto& item : cases) {
        super_workspace::State state;
        state.profile = profile;
        state.batteryPercent = item.percent;
        state.charging = charging;
        RecordingSurface surface;
        super_workspace::drawCenterBattery(surface, state);
        const auto& outline = surface.roundRectangles.at(0);
        const auto& terminal = surface.roundRectangles.at(2);
        const auto& label = surface.textDraws.at(0);
        assert(label.text == item.label && label.datum == middle_left);
        assert(label.x - (terminal[0] + terminal[2]) == 8);
        const double center = (outline[0] + label.x + item.textWidth) / 2.0;
        assert(std::abs(center - 233.0) <= 1.0);
        assert(label.y == 300 && outline[1] + outline[3] / 2 == 300);
        assert(!surface.fontLoaded);
      }
    }
  }
}

void testCircularRendererRetainsLabelsAndPalette() {
  super_workspace::State state;
  state.profile = super_workspace::Profile::Hermes;
  state.borderColors = {0xFFFF, 0xFFE0, 0x07FF, 0xF81F};
  state.swipeDirection = touch_gesture::Direction::Right;
  RecordingSurface surface;
  super_workspace::render(surface, state);
  assert(surface.circles.size() == 10);
  for (std::size_t i=0; i<4; ++i) {
    const auto& disc = surface.circles[i*2+1];
    assert(disc[2] == 53);
    assert(disc[3] == (i == 1 ? super_workspace::shade565(state.borderColors[i], 0.72f) : state.borderColors[i]));
  }
  auto contains = [&](const char* text) {
    return std::find(surface.texts.begin(), surface.texts.end(), text) != surface.texts.end();
  };
  assert(contains("HERMES") && contains("OPEN") && contains("CYCLE"));
  assert(!contains("NEW") && !contains("PROJECT"));
  assert(contains("OFFLINE") && contains("--%"));
  assert(!contains("BACK") && !contains("TAB"));
}

void testPendingProfilesShowPromptWithoutLosingConnectionOrBattery() {
  using namespace super_workspace;
  for (auto profile : {Profile::Super, Profile::Deepseek, Profile::Hermes})
  for (auto item : {std::make_pair(HermesPresentation::Idle, "TAP TO OPEN"),
                    std::make_pair(HermesPresentation::Opening, "OPENING"),
                    std::make_pair(HermesPresentation::Error, "TAP TO RETRY")}) {
    State state;
    state.profile = profile;
    state.hermesPresentation = item.first;
    state.connected = true;
    state.batteryPercent = 100;
    RecordingSurface surface;
    render(surface, state);
    auto has = [&](const char* text) {
      return std::find(surface.texts.begin(), surface.texts.end(), text) != surface.texts.end();
    };
    const char* title = profile == Profile::Deepseek ? "DSH"
        : profile == Profile::Hermes ? "HERMES" : "SUPER";
    assert(has(title) && has(item.second) && has("CONNECTED") && has("100%"));
    for (std::size_t i=0;i<4;++i)
      assert(surface.circles[i*2+1][3] == (i==3 ? state.borderColors[i] : kMuted));
    for (const auto& draw : surface.textDraws) {
      if (draw.text == item.second) assert(draw.x == 233 && draw.y == 270);
      if (draw.text == "CONNECTED") assert(draw.x == 233 && draw.y == 185);
    }
  }
}

template <typename T, typename = void>
struct HasProjectName : std::false_type {};
template <typename T>
struct HasProjectName<
    T, std::void_t<decltype(std::declval<T>().projectName)>>
    : std::true_type {};

template <typename T, typename = void>
struct HasSessionName : std::false_type {};
template <typename T>
struct HasSessionName<
    T, std::void_t<decltype(std::declval<T>().sessionName)>>
    : std::true_type {};

template <typename T, typename = void>
struct HasQuotaAvailable : std::false_type {};
template <typename T>
struct HasQuotaAvailable<
    T, std::void_t<decltype(std::declval<T>().quotaAvailable)>>
    : std::true_type {};

template <typename T, typename = void>
struct HasRemainingPercent : std::false_type {};
template <typename T>
struct HasRemainingPercent<
    T, std::void_t<decltype(std::declval<T>().remainingPercent)>>
    : std::true_type {};

void assertPoint(super_workspace::Point actual, int expectedX,
                 int expectedY) {
  assert(actual.x == expectedX);
  assert(actual.y == expectedY);
}

void testDirectionalGeometryAndPalette() {
  using touch_gesture::Direction;

  assert(std::strcmp(super_workspace::kTitle, "SUPER") == 0);
  static_assert(super_workspace::kWidth == 466);
  static_assert(super_workspace::kHeight == 466);
  static_assert(super_workspace::kBackground == 0x0000);
  const auto& controls = super_workspace::kDirectionalControls;
  const super_workspace::Point expected[] = {{233,72},{398,237},{233,402},{68,237}};
  const Direction directions[] = {Direction::Up,Direction::Right,Direction::Down,Direction::Left};
  for (std::size_t i=0;i<4;++i) {
    assert(controls[i].direction == directions[i]);
    assert(controls[i].center == expected[i]);
    const int dx=controls[i].center.x-233,dy=controls[i].center.y-237;
    assert(dx*dx+dy*dy > (104+56)*(104+56));
    const int screenDx=controls[i].center.x-233,screenDy=controls[i].center.y-233;
    assert(std::sqrt(double(screenDx*screenDx+screenDy*screenDy))+56 <= 233);
  }

}

void testDedicatedVisualState() {
  using super_workspace::State;
  using touch_gesture::Direction;

  State state;
  state.batteryPercent = 63;
  state.charging = true;
  state.connected = true;
  state.swipeDirection = Direction::Right;
  state.powerOverlay = super_workspace::PowerOverlay::HoldToPowerOff;
  state.powerHoldProgress = 0.5f;
  assert(state.batteryPercent == 63);
  assert(state.charging);
  assert(state.connected);
  assert(state.swipeDirection == Direction::Right);
}

void testNoUserContentOrCodexTelemetryFields() {
  using State = super_workspace::State;
  static_assert(!HasProjectName<State>::value);
  static_assert(!HasSessionName<State>::value);
  static_assert(!HasQuotaAvailable<State>::value);
  static_assert(!HasRemainingPercent<State>::value);
}

}  // namespace

void testDeepseekSharesFourDirectionalControls() {
  super_workspace::State state;
  state.profile = super_workspace::Profile::Deepseek;
  RecordingSurface surface;
  super_workspace::render(surface, state);
  auto has = [&](const char* text) {
    return std::find(surface.texts.begin(), surface.texts.end(), text) != surface.texts.end();
  };
  assert(has("DSH") && !has("DeepSeek") && !has("Deepseek") && !has("DEEPSEEK"));
  assert(has("CYCLE") && has("OFFLINE") && has("--%"));
  assert(has("PREV") && has("NEXT") && has("VIEW"));
  assert(!has("TAB") && !has("OPEN"));
  assert(surface.circles.size() == 10);
  for (std::size_t i = 0; i < 4; ++i)
    assert(surface.circles[i * 2 + 1][3] == state.borderColors[i]);
}

void testTitlesShareFontAndFitMeasuredInterior() {
  using namespace super_workspace;
  for (auto profile : {Profile::Super, Profile::Hermes, Profile::Deepseek}) {
    for (auto presentation : {HermesPresentation::Active, HermesPresentation::Idle,
                              HermesPresentation::Opening, HermesPresentation::Error}) {
      State state;
      state.profile = profile;
      state.hermesPresentation = presentation;
      RecordingSurface surface;
      surface.setTextSize(2.0f); // renderer must reset before measuring
      drawCenterPanel(surface, state);
      const auto& title = surface.textDraws.at(0);
      assert(title.font == dashboard::font_data::kSpaceMono46Vlw);
      assert(title.datum == middle_center && title.x == 233);
      assert(title.y == 228);
      assert(title.width <= 178);
      if (presentation == HermesPresentation::Active) {
        surface.loadFont(title.font);
        surface.setTextSize(1.0f);
        std::printf("PASS title %s: base width %dpx, scale %.6f, drawn width %dpx\n",
                    title.text.c_str(), surface.textWidth(title.text.c_str()), title.size, title.width);
        surface.unloadFont();
      }
      assert(title.x - title.width / 2 >= 144);
      assert(title.x + (title.width + 1) / 2 <= 322);
      if (profile == Profile::Deepseek) {
        assert(title.text == "DSH" && title.text.size() == 3);
      }
      assert(title.size == 1.0f);
      assert(!surface.fontLoaded);
    }
  }
}

int main() {
  testTitlesShareFontAndFitMeasuredInterior();
  testDeepseekSharesFourDirectionalControls();
  testPendingProfilesShowPromptWithoutLosingConnectionOrBattery();
  testBatteryAndLabelAreCenteredAsOneMeasuredGroup();
  testCircularRendererRetainsLabelsAndPalette();
  testDirectionalGeometryAndPalette();
  testDedicatedVisualState();
  testNoUserContentOrCodexTelemetryFields();
}
