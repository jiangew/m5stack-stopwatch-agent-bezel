// SPDX-License-Identifier: MIT
#pragma once

#include <cmath>
#include <cstdint>
#include <initializer_list>

#include "RobotHomeCharacter.h"
#include "RobotHomeInteraction.h"

namespace robot_home {

struct Point {
  int x;
  int y;
};

namespace character_art {

struct Transform {
  float scale = 1.0f;
  float tilt = 0.0f;
  int bob = 0;

  Point apply(Point point) const {
    const float x = (point.x - 233) * scale;
    const float y = (point.y - 225) * scale;
    const float sine = std::sin(tilt);
    const float cosine = std::cos(tilt);
    return {233 + static_cast<int>(x * cosine - y * sine),
            225 + bob + static_cast<int>(x * sine + y * cosine)};
  }
};

template <class Surface>
void fillPoly(Surface& surface, const Transform& transform,
              std::initializer_list<Point> points, std::uint16_t color) {
  auto iterator = points.begin();
  const Point first = transform.apply(*iterator++);
  Point previous = transform.apply(*iterator++);
  for (; iterator != points.end(); ++iterator) {
    const Point next = transform.apply(*iterator);
    surface.fillTriangle(first.x, first.y, previous.x, previous.y, next.x,
                         next.y, color);
    previous = next;
  }
}

inline std::uint16_t talkingEye(std::uint16_t base, Mood mood,
                                float speechPulse) {
  return mood == Mood::Talking && speechPulse > 0.5f ? 0xBFFF : base;
}

template <class Surface>
void drawBumblebee(Surface& surface, const Transform& transform,
                   std::uint16_t eyeColor, int mouthOffset,
                   std::uint16_t outline) {
  constexpr std::uint16_t yellow = 0xFE67;
  constexpr std::uint16_t light = 0xFF30;
  constexpr std::uint16_t dark = 0x2146;
  constexpr std::uint16_t metal = 0x9D78;

  fillPoly(surface, transform,
           {{105, 173}, {120, 130}, {157, 102}, {309, 102}, {346, 130},
            {361, 173}, {355, 271}, {311, 316}, {155, 316}, {111, 271}},
           outline);
  fillPoly(surface, transform, {{120, 151}, {131, 91}, {151, 91}, {163, 156}},
           yellow);
  fillPoly(surface, transform, {{346, 151}, {335, 91}, {315, 91}, {303, 156}},
           yellow);
  fillPoly(surface, transform,
           {{116, 181}, {131, 145}, {164, 119}, {202, 105}, {264, 105},
            {302, 119}, {335, 145}, {350, 181}, {344, 257}, {312, 294},
            {277, 314}, {189, 314}, {154, 294}, {122, 257}},
           yellow);
  fillPoly(surface, transform, {{215, 105}, {251, 105}, {247, 173}, {219, 173}},
           dark);
  fillPoly(surface, transform, {{226, 112}, {240, 112}, {240, 154}, {226, 154}},
           0x5B4D);
  fillPoly(surface, transform, {{132, 160}, {190, 126}, {198, 163}, {145, 187}},
           light);
  fillPoly(surface, transform, {{334, 160}, {276, 126}, {268, 163}, {321, 187}},
           light);
  fillPoly(surface, transform,
           {{132, 187}, {190, 163}, {220, 182}, {246, 182}, {276, 163},
            {334, 187}, {319, 246}, {282, 279}, {184, 279}, {147, 246}},
           dark);
  fillPoly(surface, transform, {{146, 190}, {190, 174}, {215, 190}, {198, 229}, {155, 224}},
           eyeColor);
  fillPoly(surface, transform, {{320, 190}, {276, 174}, {251, 190}, {268, 229}, {311, 224}},
           eyeColor);
  fillPoly(surface, transform, {{220, 207}, {246, 207}, {253, 242}, {233, 253}, {213, 242}},
           0x73EF);
  fillPoly(surface, transform,
           {{174, 246 + mouthOffset}, {207, 237 + mouthOffset},
            {233, 251 + mouthOffset}, {259, 237 + mouthOffset},
            {292, 246 + mouthOffset}, {284, 282 + mouthOffset},
            {258, 301 + mouthOffset}, {208, 301 + mouthOffset},
            {182, 282 + mouthOffset}},
           metal);
  fillPoly(surface, transform,
           {{198, 258 + mouthOffset}, {216, 264 + mouthOffset},
            {250, 264 + mouthOffset}, {268, 258 + mouthOffset},
            {264, 270 + mouthOffset}, {202, 270 + mouthOffset}},
           dark);
}

template <class Surface>
void drawOptimus(Surface& surface, const Transform& transform,
                 std::uint16_t eyeColor, int faceplateOffset,
                 std::uint16_t outline) {
  constexpr std::uint16_t blue = 0x241F;
  constexpr std::uint16_t blueLight = 0x451F;
  constexpr std::uint16_t red = 0xF145;
  constexpr std::uint16_t dark = 0x18E4;
  constexpr std::uint16_t silver = 0xBDF7;
  constexpr std::uint16_t light = 0xE71C;

  fillPoly(surface, transform,
           {{115, 302}, {120, 116}, {143, 84}, {163, 167}, {183, 116},
            {208, 98}, {258, 98}, {283, 116}, {303, 167}, {323, 84},
            {346, 116}, {351, 302}},
           outline);
  fillPoly(surface, transform, {{126, 267}, {126, 99}, {145, 89}, {158, 177}, {151, 284}}, blue);
  fillPoly(surface, transform, {{340, 267}, {340, 99}, {321, 89}, {308, 177}, {315, 284}}, blue);
  fillPoly(surface, transform,
           {{156, 174}, {184, 126}, {211, 108}, {255, 108}, {282, 126},
            {310, 174}, {302, 256}, {270, 303}, {196, 303}, {164, 256}},
           blue);
  fillPoly(surface, transform, {{207, 108}, {259, 108}, {249, 180}, {217, 180}}, blueLight);
  fillPoly(surface, transform, {{217, 113}, {249, 113}, {242, 160}, {224, 160}}, dark);
  fillPoly(surface, transform, {{151, 184}, {215, 165}, {218, 204}, {176, 220}}, blueLight);
  fillPoly(surface, transform, {{315, 184}, {251, 165}, {248, 204}, {290, 220}}, blueLight);
  fillPoly(surface, transform, {{169, 192}, {211, 181}, {225, 195}, {207, 216}, {175, 211}}, eyeColor);
  fillPoly(surface, transform, {{297, 192}, {255, 181}, {241, 195}, {259, 216}, {291, 211}}, eyeColor);
  fillPoly(surface, transform, {{154, 271}, {187, 279}, {200, 317}, {158, 297}}, red);
  fillPoly(surface, transform, {{312, 271}, {279, 279}, {266, 317}, {308, 297}}, red);
  fillPoly(surface, transform,
           {{197, 211 + faceplateOffset}, {222, 202 + faceplateOffset},
            {233, 219 + faceplateOffset}, {244, 202 + faceplateOffset},
            {269, 211 + faceplateOffset}, {263, 288 + faceplateOffset},
            {233, 313 + faceplateOffset}, {203, 288 + faceplateOffset}},
           silver);
  fillPoly(surface, transform,
           {{222, 220 + faceplateOffset}, {233, 229 + faceplateOffset},
            {244, 220 + faceplateOffset}, {241, 286 + faceplateOffset},
            {233, 298 + faceplateOffset}, {225, 286 + faceplateOffset}},
           light);
  for (int y = 232; y <= 278; y += 12)
    fillPoly(surface, transform,
             {{213, y + faceplateOffset}, {253, y + faceplateOffset},
              {250, y + 5 + faceplateOffset}, {216, y + 5 + faceplateOffset}},
             dark);
}

template <class Surface>
void drawMegatron(Surface& surface, const Transform& transform,
                  std::uint16_t eyeColor, int jawOffset,
                  std::uint16_t outline) {
  constexpr std::uint16_t black = 0x10A2;
  constexpr std::uint16_t dark = 0x3186;
  constexpr std::uint16_t gunmetal = 0x6B4D;
  constexpr std::uint16_t metal = 0xA514;
  constexpr std::uint16_t light = 0xCE79;

  fillPoly(surface, transform,
           {{99, 234}, {122, 143}, {166, 108}, {203, 78}, {234, 101},
            {269, 75}, {302, 116}, {347, 145}, {371, 239}, {332, 310},
            {278, 329}, {188, 329}, {132, 306}},
           outline);
  fillPoly(surface, transform,
           {{120, 230}, {133, 149}, {171, 119}, {204, 88}, {236, 113},
            {266, 84}, {296, 124}, {335, 151}, {350, 230}, {319, 287},
            {277, 316}, {189, 316}, {145, 286}},
           gunmetal);
  fillPoly(surface, transform, {{132, 151}, {195, 96}, {182, 181}, {141, 224}}, light);
  fillPoly(surface, transform, {{334, 151}, {267, 91}, {286, 184}, {327, 223}}, metal);
  fillPoly(surface, transform, {{202, 90}, {234, 116}, {218, 181}, {181, 175}}, dark);
  fillPoly(surface, transform, {{266, 86}, {237, 113}, {248, 183}, {286, 184}}, dark);
  fillPoly(surface, transform, {{134, 219}, {184, 178}, {225, 190}, {204, 229}, {158, 238}}, black);
  fillPoly(surface, transform, {{332, 218}, {282, 178}, {241, 190}, {262, 229}, {308, 238}}, black);
  fillPoly(surface, transform, {{158, 210}, {198, 194}, {218, 204}, {201, 221}, {168, 223}}, eyeColor);
  fillPoly(surface, transform, {{308, 210}, {268, 194}, {248, 204}, {265, 221}, {298, 223}}, eyeColor);
  fillPoly(surface, transform, {{217, 197}, {249, 197}, {253, 244}, {233, 256}, {213, 244}}, metal);
  fillPoly(surface, transform,
           {{170, 239}, {206, 227}, {233, 253}, {260, 227}, {296, 239},
            {285, 283}, {262, 300}, {251, 323 + jawOffset},
            {215, 323 + jawOffset}, {204, 300}, {181, 283}},
           dark);
  fillPoly(surface, transform,
           {{199, 266 + jawOffset}, {218, 274 + jawOffset},
            {248, 274 + jawOffset}, {267, 266 + jawOffset},
            {257, 293 + jawOffset}, {209, 293 + jawOffset}},
           metal);
  fillPoly(surface, transform, {{223, 299 + jawOffset}, {243, 299 + jawOffset}, {248, 319 + jawOffset}, {218, 319 + jawOffset}}, black);
}

template <class Surface>
void drawStarscream(Surface& surface, const Transform& transform,
                    std::uint16_t eyeColor, int chinOffset,
                    std::uint16_t outline) {
  constexpr std::uint16_t black = 0x1082;
  constexpr std::uint16_t dark = 0x2945;
  constexpr std::uint16_t silver = 0xA514;
  constexpr std::uint16_t light = 0xDEFB;
  constexpr std::uint16_t red = 0xD925;

  fillPoly(surface, transform,
           {{91, 303}, {118, 109}, {151, 82}, {169, 176}, {204, 111},
            {233, 77}, {262, 111}, {297, 176}, {315, 82}, {348, 109},
            {375, 303}, {314, 326}, {152, 326}},
           outline);
  fillPoly(surface, transform, {{104, 292}, {129, 104}, {151, 90}, {164, 203}, {141, 305}}, silver);
  fillPoly(surface, transform, {{362, 292}, {337, 104}, {315, 90}, {302, 203}, {325, 305}}, silver);
  fillPoly(surface, transform, {{128, 274}, {108, 154}, {157, 189}, {180, 286}}, red);
  fillPoly(surface, transform, {{338, 274}, {358, 154}, {309, 189}, {286, 286}}, red);
  fillPoly(surface, transform,
           {{164, 177}, {199, 120}, {233, 90}, {267, 120}, {302, 177},
            {285, 278}, {253, 322}, {213, 322}, {181, 278}},
           silver);
  fillPoly(surface, transform, {{204, 122}, {233, 91}, {262, 122}, {246, 190}, {220, 190}}, light);
  fillPoly(surface, transform, {{159, 190}, {210, 164}, {227, 193}, {203, 225}, {171, 218}}, dark);
  fillPoly(surface, transform, {{307, 190}, {256, 164}, {239, 193}, {263, 225}, {295, 218}}, dark);
  fillPoly(surface, transform, {{175, 195}, {208, 181}, {224, 195}, {207, 210}, {184, 208}}, eyeColor);
  fillPoly(surface, transform, {{291, 195}, {258, 181}, {242, 195}, {259, 210}, {282, 208}}, eyeColor);
  fillPoly(surface, transform, {{219, 188}, {247, 188}, {252, 252}, {233, 278}, {214, 252}}, light);
  fillPoly(surface, transform,
           {{185, 225}, {213, 244}, {233, 278}, {253, 244}, {281, 225},
            {270, 282}, {247, 305 + chinOffset}, {233, 331 + chinOffset},
            {219, 305 + chinOffset}, {196, 282}},
           silver);
  fillPoly(surface, transform, {{212, 262}, {233, 276}, {254, 262}, {249, 286}, {217, 286}}, black);
}

}  // namespace character_art

template <class Surface>
void renderCharacter(Surface& surface, Character character, Mood mood,
                     std::uint32_t nowMs, float transitionProgress) {
  const float phase = (nowMs % 4400) / 4400.0f * 6.2831853f;
  const float pulsePhase = (nowMs % 320) / 320.0f * 6.2831853f;
  const float speechPulse = (1.0f + std::sin(pulsePhase)) * 0.5f;
  const float progress = transitionProgress < 0.0f
                             ? 0.0f
                             : (transitionProgress > 1.0f ? 1.0f
                                                          : transitionProgress);
  const float eased = 1.0f - (1.0f - progress) * (1.0f - progress);
  character_art::Transform transform;
  transform.scale = 0.86f + eased * 0.14f;
  transform.bob = static_cast<int>(std::sin(phase) * 3);
  if (mood == Mood::Happy)
    transform.tilt = std::sin((nowMs % 700) / 700.0f * 6.2831853f) * 0.10f;

  const int speechOffset = mood == Mood::Talking
                               ? static_cast<int>(speechPulse * 5)
                               : 0;
  const std::uint16_t blueEye = character_art::talkingEye(0x7F5F, mood, speechPulse);
  const std::uint16_t redEye = character_art::talkingEye(0xF945, mood, speechPulse);

  switch (character) {
    case Character::Bumblebee:
      character_art::drawBumblebee(surface, transform, blueEye, speechOffset,
                                   progress < 1.0f ? 0xFE67 : 0x2146);
      break;
    case Character::Optimus:
      character_art::drawOptimus(surface, transform, blueEye, speechOffset,
                                 progress < 1.0f ? 0x07FF : 0x18E4);
      break;
    case Character::Megatron:
      character_art::drawMegatron(surface, transform, redEye, speechOffset,
                                  progress < 1.0f ? 0xB81F : 0x2104);
      break;
    case Character::Starscream:
      character_art::drawStarscream(surface, transform, redEye, speechOffset,
                                    progress < 1.0f ? 0xF9A7 : 0x2104);
      break;
  }
}

}  // namespace robot_home
