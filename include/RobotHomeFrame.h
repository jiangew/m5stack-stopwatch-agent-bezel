// SPDX-License-Identifier: MIT
#pragma once
#include <cstdint>

namespace robot_home {
// One clock for all Home frames. Input and telemetry bypass animation cadence.
class FrameClock {
 public:
  bool due(std::uint32_t now, bool visible, bool animated, bool changed) {
    if (!visible) { valid_ = false; return false; }
    return !valid_ || changed || (animated_ && !animated) ||
           (animated && static_cast<std::uint32_t>(now - last_) >= 34);
  }
  void presented(std::uint32_t now, bool animated) {
    last_ = now; animated_ = animated; valid_ = true;
  }
 private:
  std::uint32_t last_ = 0;
  bool valid_ = false, animated_ = false;
};
}
