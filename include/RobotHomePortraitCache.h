// SPDX-License-Identifier: MIT
#pragma once
#include <array>
#include <cstddef>
#include <cstdint>

namespace robot_home {
struct PortraitImage { const std::uint8_t* bytes; std::uint32_t size; };

// Sprite is injected so allocation/decode failures can be tested on the host.
// Full cache: 7 * 300 * 300 * 2 bytes in PSRAM. Fallback: one reused sprite.
template <class Sprite>
class PortraitCache {
 public:
  ~PortraitCache() { clear(); }
  PortraitCache() = default;
  PortraitCache(const PortraitCache&) = delete;
  PortraitCache& operator=(const PortraitCache&) = delete;

  void prepare(const PortraitImage* images, std::size_t count) {
    if (prepared_) return;
    prepared_ = true;
    count_ = count < kCapacity ? count : kCapacity;
    for (std::size_t i = 0; i < count_; ++i) images_[i] = images[i];
    for (std::size_t i = 0; i < count_; ++i) {
      if (!allocate(i, true)) {
        releaseSprites();
        fallback_ = true;
        allocate(0, false); // bounded, single-buffer internal-memory fallback
        return;
      }
      decoded_[i] = decode(i, images_[i]);
      failed_[i] = !decoded_[i];
    }
  }

  template <class Canvas>
  bool draw(Canvas& canvas, PortraitImage image, float cx, float cy,
            float scale, float angle) {
    std::size_t index = 0;
    while (index < count_ && images_[index].bytes != image.bytes) ++index;
    if (index == count_ || failed_[index]) return false;
    const std::size_t slot = fallback_ ? 0 : index;
    if (!allocated_[slot]) return false;
    if (fallback_ && current_ != image.bytes) {
      current_ = nullptr; // failed decode overwrites the reused pixels too
      decoded_[0] = decode(0, image);
      if (!decoded_[0]) { failed_[index] = true; return false; }
      current_ = image.bytes;
    }
    if (!decoded_[slot]) return false;
    sprites_[slot].pushRotateZoom(&canvas, cx, cy, angle, scale, scale, 0);
    return true;
  }

  void clear() {
    releaseSprites();
    images_ = {}; failed_ = {}; current_ = nullptr;
    count_ = 0; prepared_ = false; fallback_ = false;
  }
 private:
  bool allocate(std::size_t slot, bool psram) {
    auto& sprite = sprites_[slot];
    sprite.setPsram(psram);
    sprite.setColorDepth(16);
    allocated_[slot] = sprite.createSprite(300, 300) != nullptr;
    if (allocated_[slot]) sprite.setPivot(150, 150);
    return allocated_[slot];
  }
  bool decode(std::size_t slot, PortraitImage image) {
    sprites_[slot].fillScreen(0);
    return sprites_[slot].drawJpg(image.bytes, image.size, 0, 0);
  }
  void releaseSprites() {
    for (std::size_t i = 0; i < kCapacity; ++i) {
      if (allocated_[i]) sprites_[i].deleteSprite();
      allocated_[i] = decoded_[i] = false;
    }
  }
  static constexpr std::size_t kCapacity = 7;
  std::array<Sprite, kCapacity> sprites_;
  std::array<PortraitImage, kCapacity> images_{};
  std::array<bool, kCapacity> allocated_{}, decoded_{}, failed_{};
  const std::uint8_t* current_ = nullptr;
  std::size_t count_ = 0;
  bool prepared_ = false, fallback_ = false;
};
}
