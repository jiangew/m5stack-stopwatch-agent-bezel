// SPDX-License-Identifier: MIT
#pragma once
#include <cstdint>
#include "TouchGesture.h"
namespace robot_home {
enum class Mood : std::uint8_t { Idle, Happy, Surprise, Sleep, Connect, Blink };
enum class BlinkFrame : std::uint8_t { Open, Half, Closed };
constexpr std::uint32_t kBlinkCount = 3;
constexpr std::uint32_t kBlinkCycleMs = 360;
constexpr std::uint32_t kBlinkOpenGapMs = 120;
constexpr std::uint32_t kBlinkPeriodMs = kBlinkCycleMs + kBlinkOpenGapMs;
constexpr std::uint32_t kBlinkDurationMs =
    kBlinkCount * kBlinkCycleMs + (kBlinkCount - 1) * kBlinkOpenGapMs;
// Elapsed from the accepted tap, never the absolute uptime phase. Keep the
// reaction active through both open gaps so taps cannot restart or queue it.
constexpr BlinkFrame blinkFrame(std::uint32_t elapsed) {
  if (elapsed >= kBlinkDurationMs) return BlinkFrame::Open;
  const auto phase = elapsed % kBlinkPeriodMs;
  return phase < 70 ? BlinkFrame::Half
       : phase < 230 ? BlinkFrame::Closed
       : phase < kBlinkCycleMs ? BlinkFrame::Half : BlinkFrame::Open;
}
class Animation {
 public:
  void react(Mood mood, std::uint32_t now) { mood_=mood; since_=now; duration_=2400; }
  bool blink(std::uint32_t now) {
    if (mood(now) == Mood::Blink) return false; // no restart or replay queue
    mood_=Mood::Blink;since_=now;duration_=kBlinkDurationMs;return true;
  }
  std::uint32_t elapsed(std::uint32_t now) const { return now-since_; }
  Mood mood(std::uint32_t now) const {
    return static_cast<std::uint32_t>(now-since_) >= duration_ ? Mood::Idle : mood_;
  }
  void random(std::uint32_t now, std::uint32_t entropy) {
    const Mood choices[]{Mood::Happy,Mood::Surprise,Mood::Sleep};
    Mood selected=choices[entropy%3];
    if(selected==mood(now)) selected=choices[(entropy%3+1)%3];
    react(selected,now);
  }
  bool frameDue(std::uint32_t now, bool visible) {
    if(!visible) { framed_=false;return false; }
    if(framed_ && static_cast<std::uint32_t>(now-lastFrame_)<50) return false;
    framed_=true;lastFrame_=now;return true;
  }
 private:
  Mood mood_=Mood::Idle;
  std::uint32_t since_=0,lastFrame_=0,duration_=2400;
  bool framed_=false;
};
constexpr bool inHead(int x,int y) { return x>=88 && x<=378 && y>=108 && y<=319; }
class Tap {
 public:
  void begin(int x,int y,std::uint32_t now,bool awake) {
    eligible_=awake&&inHead(x,y);x_=x;y_=y;since_=now;
  }
  void move(int x,int y,int threshold) {
    if(touch_gesture::classifySwipe(x-x_,y-y_,threshold)!=touch_gesture::Direction::None)eligible_=false;
  }
  bool finish(int x,int y,std::uint32_t now,int threshold) {
    move(x,y,threshold);
    const bool accepted=eligible_&&inHead(x,y)&&static_cast<std::uint32_t>(now-since_)<500;
    cancel();return accepted;
  }
  void cancel(){eligible_=false;}
 private:
  bool eligible_=false;int x_=0,y_=0;std::uint32_t since_=0;
};
}
