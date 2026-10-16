#include <cassert>
#include <cmath>
#include <cstdio>
#include "RobotHomeImu.h"
using namespace robot_home::imu;

namespace {
// Literal gravity vectors for +/-10 degree roll. Gyro keeps the pose Held.
const Sample positiveRoll{0,.17364818f,.98480775f,25,0,0};
const Sample negativeRoll{0,-.17364818f,.98480775f,25,0,0};
const Sample movingLevel{0,0,1,25,0,0};
struct Trace {
  Detector detector;
  std::uint32_t now;
  Result last;
  unsigned pickups=0,settles=0;
  explicit Trace(std::uint32_t start=0):now(start) {}
  Result step(const Sample& sample,unsigned elapsed=20) {
    now+=elapsed;last=detector.update(sample,now);
    pickups+=last.event==Event::Pickup;settles+=last.event==Event::Settled;
    return last;
  }
  void ready() {
    step({},0);
    for(unsigned i=0;i<1480;i+=20)step({});
    assert(last.phase==Phase::Calibrating); // startup still needs 1500ms
    step({});assert(last.phase==Phase::Resting);
    assert(pickups==0&&settles==0);
  }
  void pickup() {
    step(movingLevel);
    step(movingLevel);step(movingLevel);
    assert(last.phase==Phase::Resting); // 40ms is insufficient
    step(movingLevel);
    assert(last.event==Event::Pickup&&last.phase==Phase::Held);
  }
};
void rollResponse(unsigned interval,std::uint32_t start=0) {
  Trace t(start);t.ready();t.pickup();
  for(unsigned elapsed=0;elapsed<180;elapsed+=interval)t.step(positiveRoll,interval);
  const float positive=t.last.pose.angle;
  for(unsigned elapsed=0;elapsed<180;elapsed+=interval)t.step(negativeRoll,interval);
  const float negative=t.last.pose.angle;
  std::printf("roll interval=%u wrap=%s: +180ms=%.6f deg, reverse180ms=%.6f deg\n",
      interval,start?"yes":"no",positive,negative);
  std::fflush(stdout);
  // Final unsaturated angle is 1.89 degrees. Check a physical response range,
  // independent of the production filter formula.
  assert(positive>=1.70f&&positive<=2.00f);
  assert(negative<-1.50f&&negative>=-2.00f);
  for(unsigned elapsed=0;elapsed<900;elapsed+=interval)t.step(negativeRoll,interval);
  assert(std::fabs(t.last.pose.angle+1.89f)<.01f);
  assert(t.last.pose.x<0&&t.last.pose.y==0); // retain accepted roll -> angle/x
  assert(t.pickups==1&&t.settles==0);
}
void settledResponse(std::uint32_t start=0) {
  Trace t(start);t.ready();t.pickup();
  for(unsigned i=0;i<180;i+=20)t.step(positiveRoll);
  const Sample stillPositive{0,.17364818f,.98480775f,0,0,0};
  const Sample stillNegative{0,-.17364818f,.98480775f,0,0,0};
  t.step(stillPositive);const auto firstStill=t.now;
  for(unsigned i=0;i<580;i+=20)t.step(stillPositive);
  assert(t.now-firstStill==580&&t.settles==0&&t.last.phase==Phase::Held);
  t.step(stillPositive);
  assert(t.now-firstStill==600&&t.settles==1&&t.last.event==Event::Settled);
  assert(t.last.since==firstStill&&t.last.phase==Phase::Resting);
  assert(t.last.pose.angle==0&&t.last.pose.x==0&&t.last.pose.y==4&&t.last.pose.scale==.95f);
  for(unsigned i=0;i<600;i+=20)t.step(stillPositive);
  assert(t.settles==1&&t.last.event==Event::None);
  t.pickup();assert(t.pickups==2); // no recalibration between cycles
  for(unsigned i=0;i<180;i+=20)t.step(negativeRoll);
  assert(t.last.phase==Phase::Held&&t.last.pose.angle<0);
  t.step(stillNegative);const auto interruptedStill=t.now;
  for(unsigned i=0;i<400;i+=20)t.step(stillNegative);
  assert(t.now-interruptedStill==400&&t.settles==1);
  auto interruption=stillNegative;interruption.gx=10;t.step(interruption);
  t.step(stillNegative);const auto restartedStill=t.now;
  for(unsigned i=0;i<580;i+=20)t.step(stillNegative);
  assert(t.now-restartedStill==580&&t.settles==1&&t.last.phase==Phase::Held);
  t.step(stillNegative);
  assert(t.settles==2&&t.last.event==Event::Settled&&t.last.since==restartedStill);
  assert(t.last.phase==Phase::Resting&&t.last.pose.scale==.95f&&t.last.pose.y==4);
  t.step(stillNegative);assert(t.settles==2&&t.last.event==Event::None);
}
void recoveryCalibration() {
  Trace t;t.ready();t.pickup();
  t.step(positiveRoll,121); // excessive gap starts recovery, seeding this pose
  assert(t.last.phase==Phase::Calibrating&&t.last.event==Event::None);
  const Sample stillPositive{0,.17364818f,.98480775f,0,0,0};
  t.step(stillPositive); // first qualifying recovery sample
  for(unsigned i=0;i<1480;i+=20)t.step(stillPositive);
  assert(t.last.phase==Phase::Calibrating&&t.settles==0);
  t.step(stillPositive);assert(t.last.phase==Phase::Resting&&t.settles==0);
  t.detector.reset();t.step(stillPositive);
  for(unsigned i=0;i<1480;i+=20)t.step(stillPositive);
  assert(t.last.phase==Phase::Calibrating);
  t.step(stillPositive);assert(t.last.phase==Phase::Resting);
  for(unsigned i=0;i<80;i+=20)t.step(positiveRoll);
  assert(t.last.phase==Phase::Held&&t.pickups==2);
  assert(t.last.pose.angle==0&&t.last.pose.x==0&&t.last.pose.y==0);
}
}
int main() {
  for(unsigned interval:{20u,30u,45u,60u,90u})rollResponse(interval);
  rollResponse(20,0xfffff9a0u); // elapsed-time filtering crosses clock wrap
  settledResponse();settledResponse(0xfffff800u);recoveryCalibration();
  std::puts("PASS continuous tilt, 600ms settled boundary, interrupted dwell, repeated cycles, 1500ms startup/recovery and wraparound");
}
