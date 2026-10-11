#include <cassert>
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
        assert(label.y == 276 && outline[1] + outline[3] / 2 == 276);
        assert(!surface.fontLoaded);
      }
    }
  }
}

void testSharedRendererDoesNotCoverTriangleBases() {
  super_workspace::State state;
  state.profile = super_workspace::Profile::Hermes;
  state.borderColors = {0xFFFF, 0xFFE0, 0x07FF, 0xF81F};
  state.swipeDirection = touch_gesture::Direction::Right;
  RecordingSurface surface;
  super_workspace::render(surface, state);
  assert(surface.rectangles.size() == 1);
  const auto rect = surface.rectangles[0];
  assert(rect[0] > 143 && rect[1] > 143);
  assert(rect[0] + rect[2] <= 322 && rect[1] + rect[3] <= 322);
  for (std::size_t i=0; i<4; ++i) assert(surface.triangleColors[i*2] == state.borderColors[i]);
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
    const char* title = profile == Profile::Deepseek ? "DeepSeek"
        : profile == Profile::Hermes ? "HERMES" : "SUPER";
    assert(has(title) && has(item.second) && has("CONNECTED") && has("100%"));
    for (const auto& draw : surface.textDraws) {
      if (draw.text == item.second) assert(draw.x == 233 && draw.y == 222);
      if (draw.text == "CONNECTED") assert(draw.x == 233 && draw.y == 247);
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
  static_assert(super_workspace::kOutlineWidth == 5);
  static_assert(super_workspace::kCenterSquare.left == 143);
  static_assert(super_workspace::kCenterSquare.top == 143);
  static_assert(super_workspace::kCenterSquare.right == 322);
  static_assert(super_workspace::kCenterSquare.bottom == 322);
  static_assert(super_workspace::kBackground == 0x0041);
  static_assert(super_workspace::kCenterBorder == 0x372F);

  const auto& controls = super_workspace::kDirectionalControls;
  assert(controls.size() == 4);

  assert(controls[0].direction == Direction::Up);
  assertPoint(controls[0].baseStart, 143, 143);
  assertPoint(controls[0].baseEnd, 322, 143);
  assertPoint(controls[0].tip, 233, 26);
  assertPoint(controls[0].labelAnchor, 233, 91);
  assert(std::strcmp(controls[0].label, "PREV") == 0);
  assert(controls[0].borderColor == 0x26DF);

  assert(controls[1].direction == Direction::Right);
  assertPoint(controls[1].baseStart, 322, 143);
  assertPoint(controls[1].baseEnd, 322, 322);
  assertPoint(controls[1].tip, 440, 233);
  assertPoint(controls[1].labelAnchor, 375, 233);
  assert(std::strcmp(controls[1].label, "TAB") == 0);
  assert(controls[1].borderColor == 0xFCE6);

  assert(controls[2].direction == Direction::Down);
  assertPoint(controls[2].baseStart, 322, 322);
  assertPoint(controls[2].baseEnd, 143, 322);
  assertPoint(controls[2].tip, 233, 440);
  assertPoint(controls[2].labelAnchor, 233, 387);
  assert(std::strcmp(controls[2].label, "NEXT") == 0);
  assert(controls[2].borderColor == 0xEA7F);

  assert(controls[3].direction == Direction::Left);
  assertPoint(controls[3].baseStart, 143, 322);
  assertPoint(controls[3].baseEnd, 143, 143);
  assertPoint(controls[3].tip, 26, 233);
  assertPoint(controls[3].labelAnchor, 90, 233);
  assert(std::strcmp(controls[3].label, "CYCLE") == 0);
  assert(controls[3].borderColor == 0x53DF);

  for (const auto& control : controls) {
    assert(control.tip.x >= 0 && control.tip.x < super_workspace::kWidth);
    assert(control.tip.y >= 0 && control.tip.y < super_workspace::kHeight);
  }
  assert(controls[0].baseStart.x == super_workspace::kCenterSquare.left);
  assert(controls[0].baseEnd.x == super_workspace::kCenterSquare.right);
  assert(controls[1].baseStart.y == super_workspace::kCenterSquare.top);
  assert(controls[1].baseEnd.y == super_workspace::kCenterSquare.bottom);
  assert(controls[2].baseStart.x == super_workspace::kCenterSquare.right);
  assert(controls[2].baseEnd.x == super_workspace::kCenterSquare.left);
  assert(controls[3].baseStart.y == super_workspace::kCenterSquare.bottom);
  assert(controls[3].baseEnd.y == super_workspace::kCenterSquare.top);

  assert(controls[0].borderColor != controls[1].borderColor);
  assert(controls[0].borderColor != controls[2].borderColor);
  assert(controls[0].borderColor != controls[3].borderColor);
  assert(controls[1].borderColor != controls[2].borderColor);
  assert(controls[1].borderColor != controls[3].borderColor);
  assert(controls[2].borderColor != controls[3].borderColor);
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
  assert(has("DeepSeek") && !has("Deepseek") && !has("DEEPSEEK"));
  assert(has("CYCLE") && has("OFFLINE") && has("--%"));
  assert(has("PREV") && has("NEXT") && has("VIEW"));
  assert(!has("TAB") && !has("OPEN"));
  assert(surface.triangleColors.size() == 8);
  for (std::size_t i = 0; i < 4; ++i)
    assert(surface.triangleColors[i * 2] == state.borderColors[i]);
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
      assert(title.y == (presentation == HermesPresentation::Active ? 190 : 182));
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
        assert(title.text == "DeepSeek" && title.text.size() == 8);
        assert(title.size < 1.0f && title.size > 0.7f);
        assert(title.width >= 168);
      } else {
        assert(title.size == 1.0f);
      }
      assert(!surface.fontLoaded);
    }
  }
}

int main() {
  testTitlesShareFontAndFitMeasuredInterior();
  testDeepseekSharesFourDirectionalControls();
  testPendingProfilesShowPromptWithoutLosingConnectionOrBattery();
  testBatteryAndLabelAreCenteredAsOneMeasuredGroup();
  testSharedRendererDoesNotCoverTriangleBases();
  testDirectionalGeometryAndPalette();
  testDedicatedVisualState();
  testNoUserContentOrCodexTelemetryFields();
}
