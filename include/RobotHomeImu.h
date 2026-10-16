// SPDX-License-Identifier: MIT
#pragma once
#include <algorithm>
#include <cmath>
#include <cstdint>

namespace robot_home::imu {
struct Sample { float ax=0, ay=0, az=1, gx=0, gy=0, gz=0; };
enum class Phase : std::uint8_t { Calibrating, Resting, Held };
enum class Event : std::uint8_t { None, Pickup, Settled };
struct Pose { float angle=0, x=0, y=0, scale=1; };
struct Result { Event event=Event::None; Phase phase=Phase::Calibrating; Pose pose; std::uint32_t since=0; };
class Detector {
 public:
  static constexpr std::uint32_t kMotionMs=60, kCalibrationMs=1500, kStillMs=600, kMaxGapMs=120;
  Result update(const Sample& s, std::uint32_t now) {
    const float a=norm(s.ax,s.ay,s.az), g=norm(s.gx,s.gy,s.gz);
    if(!std::isfinite(a)||!std::isfinite(g)||a<.5f||a>2.0f||g>1000) {
      reset(); return result_;
    }
    if(valid_&&static_cast<std::uint32_t>(now-last_)>kMaxGapMs)reset();
    result_.event=Event::None;
    if(!valid_) {
      valid_=true; last_=now; previous_=s;
      fx_=s.ax;fy_=s.ay;fz_=s.az;
    }
    const float delta=norm(s.ax-previous_.ax,s.ay-previous_.ay,s.az-previous_.az);
    const bool still=std::fabs(a-1)<.04f&&g<4&&delta<.025f;
    const float alpha=1.0f-std::exp(-static_cast<float>(static_cast<std::uint32_t>(now-last_))/60.0f);
    fx_+=alpha*(s.ax-fx_);fy_+=alpha*(s.ay-fy_);fz_+=alpha*(s.az-fz_);
    const float roll=std::atan2(fy_,fz_)*57.2957795f;
    const float pitch=std::atan2(-fx_,std::sqrt(fy_*fy_+fz_*fz_))*57.2957795f;
    const bool orientationShift=result_.phase==Phase::Resting&&
        (std::fabs(wrapped(roll-neutralRoll_))>8||std::fabs(wrapped(pitch-neutralPitch_))>8);
    const bool moving=std::fabs(a-1)>.10f||g>18||delta>.10f||orientationShift;
    if(result_.phase==Phase::Resting) {
      if(moving) {
        if(!motionPending_) {motionPending_=true;motionAt_=now;}
        if(static_cast<std::uint32_t>(now-motionAt_)>=kMotionMs) {
          result_.phase=Phase::Held;result_.event=Event::Pickup;result_.since=motionAt_;
          stillPending_=false;motionPending_=false;
        }
      } else motionPending_=false;
    }
    if(result_.phase!=Phase::Resting) {
      if(still) {
        if(!stillPending_) {stillPending_=true;stillAt_=now;}
        const auto stillDuration=result_.phase==Phase::Calibrating?kCalibrationMs:kStillMs;
        if(static_cast<std::uint32_t>(now-stillAt_)>=stillDuration) {
          if(result_.phase==Phase::Held) {result_.event=Event::Settled;result_.since=stillAt_;}
          result_.phase=Phase::Resting;neutralRoll_=roll;neutralPitch_=pitch;
          stillPending_=false;
        }
      } else stillPending_=false;
    }
    result_.pose={};
    if(result_.phase==Phase::Held) {
      const float r=deadzone(wrapped(roll-neutralRoll_));
      const float p=deadzone(wrapped(pitch-neutralPitch_));
      result_.pose.angle=bound(r*.27f,8);
      result_.pose.x=bound(r*.33f,10);
      result_.pose.y=bound(p*.27f,8);
    } else if(result_.phase==Phase::Resting) {
      result_.pose.scale=.95f;result_.pose.y=4;
    }
    previous_=s;last_=now;
    return result_;
  }
  void reset() {
    result_={};valid_=false;motionPending_=false;stillPending_=false;
  }
  const Result& result() const {return result_;}
 private:
  static float norm(float x,float y,float z) {return std::sqrt(x*x+y*y+z*z);}
  static float bound(float x,float limit) {return std::max(-limit,std::min(limit,x));}
  static float wrapped(float degrees) {return std::remainder(degrees,360.0f);}
  static float deadzone(float degrees) {return std::fabs(degrees)<3?0:degrees-std::copysign(3.0f,degrees);}
  Result result_;
  Sample previous_;
  bool valid_=false,motionPending_=false,stillPending_=false;
  std::uint32_t last_=0,motionAt_=0,stillAt_=0;
  float fx_=0,fy_=0,fz_=1,neutralRoll_=0,neutralPitch_=0;
};
}
