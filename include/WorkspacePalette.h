// SPDX-License-Identifier: MIT
#pragma once

#include <array>
#include <cstddef>
#include <cstdint>

namespace workspace_palette {

constexpr std::uint16_t rgb565(std::uint32_t rgb) {
  return static_cast<std::uint16_t>(((rgb >> 8) & 0xF800) |
                                    ((rgb >> 5) & 0x07E0) |
                                    ((rgb >> 3) & 0x001F));
}
constexpr std::uint16_t shade565(std::uint16_t color, float factor) {
  return (static_cast<unsigned>(((color >> 11) & 31) * factor) << 11)
       | (static_cast<unsigned>(((color >> 5) & 63) * factor) << 5)
       | static_cast<unsigned>((color & 31) * factor);
}
// Single-expression constexpr also supports the standard firmware's C++11 core.
constexpr std::uint16_t controlInk(std::uint16_t color) {
  return ((((color >> 11) & 31) * 255 / 31 * 299
         + ((color >> 5) & 63) * 255 / 63 * 587
         + (color & 31) * 255 / 31 * 114) / 1000) > 150 ? 0x0000 : 0xEF7E;
}
constexpr std::array<std::uint16_t, 12> kColors = {
    rgb565(0x25D8FA), rgb565(0xFFA735), rgb565(0xEC50FF), rgb565(0x65B9FC),
    rgb565(0xFFE36A), rgb565(0x7DED93), rgb565(0xFF8397), rgb565(0xB8A0FF),
    rgb565(0x5EE3C4), rgb565(0xC7EF72), rgb565(0xFFAE86), rgb565(0xF0F4FF)};
using Colors = std::array<std::uint16_t, 4>;
constexpr Colors kInitialColors{kColors[0], kColors[1], kColors[2], kColors[3]};

class Palette {
 public:
  const Colors& colors() const { return colors_; }

  template <typename Random>
  bool acceptSwipe(std::uint32_t nowMs, Random nextRandom) {
    if (hasAccepted_ && static_cast<std::uint32_t>(nowMs - lastAccepted_) < 800)
      return false;
    Colors next{};
    for (std::size_t i = 0; i < next.size(); ++i) {
      std::array<std::uint16_t, kColors.size()> candidates{};
      std::size_t count = 0;
      for (auto color : kColors) {
        if (color == colors_[i]) continue;
        bool used = false;
        for (std::size_t j = 0; j < i; ++j) used |= next[j] == color;
        if (!used) candidates[count++] = color;
      }
      // At most four exclusions from twelve colors: always bounded/nonempty.
      next[i] = candidates[static_cast<std::uint32_t>(nextRandom()) % count];
    }
    colors_ = next;
    lastAccepted_ = nowMs;
    hasAccepted_ = true;
    return true;
  }

 private:
  Colors colors_ = kInitialColors;
  std::uint32_t lastAccepted_ = 0;
  bool hasAccepted_ = false;
};
}  // namespace workspace_palette
