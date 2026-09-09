// SPDX-License-Identifier: MIT
#pragma once
#include <cstdint>
#include "TouchGesture.h"

namespace workspace_input {
// The open interior excludes the four triangle bases.
constexpr bool inCenter(int x, int y) {
  return x > 143 && x < 322 && y > 143 && y < 322;
}

class CenterTap {
 public:
  void begin(int x, int y, std::uint32_t now, bool awake) {
    eligible_ = awake && inCenter(x, y);
    x_ = x; y_ = y; started_ = now;
  }
  void move(int x, int y, int threshold) {
    if (touch_gesture::classifySwipe(x - x_, y - y_, threshold) !=
        touch_gesture::Direction::None) eligible_ = false;
  }
  bool finish(int x, int y, std::uint32_t now, int threshold) {
    move(x, y, threshold);
    const bool accepted = eligible_ && inCenter(x, y) &&
                         static_cast<std::uint32_t>(now - started_) < 500;
    cancel();
    return accepted;
  }
  void cancel() { eligible_ = false; }
 private:
  bool eligible_ = false;
  int x_ = 0, y_ = 0;
  std::uint32_t started_ = 0;
};
}  // namespace workspace_input
