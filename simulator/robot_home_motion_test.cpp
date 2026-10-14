#include <cassert>
#include <cmath>
#include <initializer_list>
#include "RobotHomeMotion.h"

int main() {
  using namespace robot_home;
  for(int i=0;i<kCharacterCount;++i) {
    auto hero=static_cast<Character>(i);
    auto idle=motionFor(hero,Mood::Idle,0);
    assert(idle.pose==0&&idle.scale==1&&idle.offsetY==0&&idle.angle==0);
    auto press=motionFor(hero,Mood::Press,0);
    assert(press.pose==0&&std::fabs(press.scale-.97f)<.0001f);
    bool moves=false;
    for(unsigned ms=0;ms<600;++ms) {
      auto m=motionFor(hero,Mood::Skill,ms);
      assert(std::isfinite(m.scale)&&std::isfinite(m.angle)&&std::isfinite(m.offsetY));
      assert(m.scale>=.97f&&m.scale<=1.04f&&std::fabs(m.offsetY)<=4&&std::fabs(m.angle)<=3);
      assert(m.pose<=(hero==Character::BumblebeeFullbody||hero==Character::Optimus?2:hero==Character::Bumblebee?0:1));
      moves|=m.pose||m.scale!=1||m.offsetY!=0||m.angle!=0;
    }
    assert(moves);
    for(unsigned ms:{600u,601u,0xffffffffu}) {
      auto end=motionFor(hero,Mood::Skill,ms);
      assert(end.pose==0&&end.scale==1&&end.offsetY==0&&end.angle==0);
    }
  }
  // Preserve the accepted pilot's discrete body poses and exact return.
  assert(motionFor(Character::Bumblebee,Mood::Skill,0).offsetY>0); // first release frame answers
  assert(motionFor(Character::BumblebeeFullbody,Mood::Skill,0).pose==1);
  assert(motionFor(Character::BumblebeeFullbody,Mood::Skill,133).pose==2);
  assert(motionFor(Character::BumblebeeFullbody,Mood::Skill,266).pose==1);
  assert(motionFor(Character::BumblebeeFullbody,Mood::Skill,400).pose==2);
  assert(motionFor(Character::BumblebeeFullbody,Mood::Skill,533).pose==0);
  assert(motionFor(Character::Optimus,Mood::Skill,0).pose==1);
  assert(motionFor(Character::Optimus,Mood::Skill,133).pose==2);
  assert(motionFor(Character::Optimus,Mood::Skill,400).pose==1);
  assert(motionFor(Character::Optimus,Mood::Skill,533).pose==0);
}
