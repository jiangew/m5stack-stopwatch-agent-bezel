#include <cassert>
#include <cmath>
#include <cstdio>
#include <limits>
#include "RobotHomeImu.h"
using namespace robot_home::imu;

struct Trace {
  Detector detector;
  std::uint32_t now=0;
  unsigned pickups=0, settles=0;
  Result last;
  Result feed(Sample s, unsigned duration) {
    for(unsigned i=0;i<duration;i+=20) {
      now+=20; last=detector.update(s,now);
      pickups+=last.event==Event::Pickup; settles+=last.event==Event::Settled;
    }
    return last;
  }
  void ready() { feed({},1600); assert(last.phase==Phase::Resting); }
};
int main() {
  Trace t;
  t.ready();
  assert(t.pickups==0&&t.settles==0); // startup is not a user action
  for(int i=0;i<30000;++i) // ten minutes of bounded desk sensor noise
    t.feed({.003f*std::sin(float(i)),.003f*std::cos(float(i)),1.003f, .3f,-.2f,.1f},20);
  assert(t.pickups==0&&t.settles==0);
  for(int i=0;i<30;++i) { // isolated taps/knocks do not qualify
    t.feed({0,0,1.5f,0,0,0},20); t.feed({},200);
  }
  assert(t.pickups==0);
  auto start=t.now+20;
  t.feed({0,0,1.15f,0,0,0},80);
  assert(t.last.event==Event::Pickup&&t.pickups==1);
  assert(t.last.since==start&&t.now-start==60);
  t.feed({0,.5f,.8660254f,25,0,0},400);
  assert(t.last.phase==Phase::Held&&t.last.pose.angle>3);
  assert(std::fabs(t.last.pose.angle)<=8&&std::fabs(t.last.pose.x)<=10&&std::fabs(t.last.pose.y)<=8);
  t.feed({0,.5f,.8660254f,0,0,0},580);
  assert(t.settles==0);
  t.feed({0,.5f,.8660254f,0,0,0},200);
  assert(t.settles==1&&t.last.phase==Phase::Resting);
  assert(t.last.pose.scale<1&&t.last.pose.angle==0);
  t.feed({0,.5f,.8660254f,0,0,0},2000); assert(t.settles==1);

  Trace slow;slow.ready();
  Trace gentle;gentle.ready();
  for(int i=0;i<100;++i) {
    float roll=i*.003f;
    gentle.feed({0,std::sin(roll),std::cos(roll),5,0,0},20);
  }
  assert(gentle.pickups==1&&gentle.last.pose.angle>0); // slow tilt has no >18 dps impulse
  // Rotation qualifies even when accelerometer magnitude stays at 1 g.
  slow.feed({0,.3f,.953939f,22,0,0},80);
  assert(slow.pickups==1);
  slow.feed({0,0,1,0,0,0},400);
  slow.feed({0,0,1,10,0,0},20); // interrupted stillness must restart dwell
  slow.feed({},580);assert(slow.settles==0);
  slow.feed({},40);assert(slow.settles==1);

  Trace invalid;invalid.ready();
  invalid.feed({0,0,1.2f,0,0,0},40);
  invalid.feed({std::numeric_limits<float>::quiet_NaN(),0,1,0,0,0},20);
  invalid.feed({0,0,1.2f,0,0,0},40);
  assert(invalid.pickups==0);
  invalid.feed({0,0,0,0,0,0},200);
  assert(std::isfinite(invalid.last.pose.angle)&&invalid.pickups==0);

  Trace gap;gap.ready();
  gap.feed({0,0,1.2f,0,0,0},40);gap.now+=500;
  gap.feed({0,0,1.2f,0,0,0},40);assert(gap.pickups==0);
  gap.feed({},1600);assert(gap.last.phase==Phase::Resting);
  gap.detector.reset();gap.feed({0,0,1.2f,0,0,0},200);
  assert(gap.last.phase==Phase::Calibrating&&gap.pickups==0);

  Trace wrap;wrap.now=0xfffff800u;wrap.ready();
  wrap.feed({0,0,1.2f,0,0,0},80);assert(wrap.pickups==1);
  wrap.feed({},1800);assert(wrap.settles==1);
  std::puts("IMU synthetic traces passed: 600s desk noise, 30 knocks, pickup 60ms qualification; not physical measurements");
}
