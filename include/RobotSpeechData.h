// SPDX-License-Identifier: MIT
#pragma once
// Supply only audio you have permission to use. Local PCM is never published.
#if __has_include("RobotSpeechLocal.h")
#include "RobotSpeechLocal.h"
#else
#include <cstdint>
namespace robot_speech {
inline constexpr bool kAvailable = false;
inline constexpr std::uint32_t kSampleRate = 24000;
inline constexpr std::int16_t kTask[] = {0};
inline constexpr std::int16_t kLaugh[] = {0};
}
#endif
