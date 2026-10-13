// SPDX-License-Identifier: MIT
#pragma once

#include <cstdint>

#include "TouchGesture.h"

namespace robot_home {

enum class Mood : std::uint8_t {
  Idle,
  Happy,
  Surprise,
  Sleep,
  Connect,
  Press,
  Skill,
};

class Animation {
 public:
  void react(Mood mood, std::uint32_t now) {
    mood_ = mood;
    since_ = now;
    duration_ = mood == Mood::Press ? 500 : mood == Mood::Skill ? 420 : 2400;
  }

  void press(std::uint32_t now) { react(Mood::Press, now); }

  bool release(std::uint32_t now) {
    if (mood(now) != Mood::Press) return false;
    react(Mood::Skill, now);
    return true;
  }

  void cancel() {
    mood_ = Mood::Idle;
    duration_ = 0;
  }

  std::uint32_t elapsed(std::uint32_t now) const { return now - since_; }

  Mood mood(std::uint32_t now) const {
    return elapsed(now) >= duration_ ? Mood::Idle : mood_;
  }

  bool active(std::uint32_t now) const { return mood(now) != Mood::Idle; }

  void random(std::uint32_t now, std::uint32_t entropy) {
    const Mood choices[]{Mood::Happy, Mood::Surprise, Mood::Sleep};
    auto selected = choices[entropy % 3];
    if (selected == mood(now)) selected = choices[(entropy % 3 + 1) % 3];
    react(selected, now);
  }


 private:
  Mood mood_ = Mood::Idle;
  std::uint32_t since_ = 0;
  std::uint32_t duration_ = 0;
};

constexpr bool inHead(int x, int y) {
  return x >= 64 && x <= 402 && y >= 64 && y <= 398;
}

class Tap {
 public:
  void begin(int x, int y, std::uint32_t now, bool awake) {
    eligible_ = awake && inHead(x, y);
    x_ = x;
    y_ = y;
    since_ = now;
  }

  void move(int x, int y, int threshold) {
    if (!inHead(x, y) ||
        touch_gesture::classifySwipe(x - x_, y - y_, threshold) !=
            touch_gesture::Direction::None) {
      eligible_ = false;
    }
  }

  bool finish(int x, int y, std::uint32_t now, int threshold) {
    move(x, y, threshold);
    const bool accepted = eligible_ && static_cast<std::uint32_t>(now - since_) < 500;
    cancel();
    return accepted;
  }

  void cancel() { eligible_ = false; }
  bool eligible() const { return eligible_; }

 private:
  bool eligible_ = false;
  int x_ = 0;
  int y_ = 0;
  std::uint32_t since_ = 0;
};

}  // namespace robot_home
