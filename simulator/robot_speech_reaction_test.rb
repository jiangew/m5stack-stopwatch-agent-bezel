# Historical filename retained; exercises production local hero reaction.
require 'tmpdir'
repo=File.expand_path('..',__dir__)
source=File.read(File.join(repo,'src/main.cpp'))
start=source.index('void stopRobotReaction() {') or abort 'missing reaction'
finish=source.index('workspace_navigation::Gesture navigationGesture;',start) or abort 'missing boundary'
functions=source[start...finish]
fixture=<<~CPP
  #include <cassert>
  #include <initializer_list>
  #include "RobotHomeInteraction.h"
  unsigned now=100;unsigned millis(){return now;}
  bool robotInputDirty=false;
  robot_home::Animation robotAnimation;
  robot_home::Tap robotTap;
  #{functions}
  int main(){
    robotAnimation.press(now);requestRobotReaction();
    assert(robotAnimation.mood(now)==robot_home::Mood::Skill&&robotInputDirty);
    now+=100;robotAnimation.press(now);requestRobotReaction();
    assert(robotAnimation.elapsed(now)==0); // new interaction immediately wins
    now+=420;assert(robotAnimation.mood(now)==robot_home::Mood::Idle);
    for(unsigned elapsed:{0u,200u,419u}) {
      now=0xfffffff0u;robotAnimation.press(now);requestRobotReaction();now+=elapsed;
      updateRobotReaction(false);
      assert(robotAnimation.mood(now)==robot_home::Mood::Idle);
      now+=2000;updateRobotReaction(true);
      assert(robotAnimation.mood(now)==robot_home::Mood::Idle);
    }
  }
CPP
Dir.mktmpdir('hero-reaction-','/private/tmp') do |dir|
  file=File.join(dir,'test.cpp');File.write(file,fixture)
  abort 'compile failed' unless system('clang++','-std=c++17',"-I#{repo}/include",file,'-o',File.join(dir,'test'))
  abort 'reaction regression failed' unless system(File.join(dir,'test'))
end
puts 'PASS production Home skill reaction: immediate restart, expiry, cancellation'
