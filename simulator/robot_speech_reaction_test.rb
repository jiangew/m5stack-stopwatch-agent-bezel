# Regression: Home's actual reaction controller must not depend on audio APIs.
require 'tmpdir'
repo=File.expand_path('..',__dir__)
source=File.read(File.join(repo,'src/main.cpp'))
start=source.index('void stopRobotReaction() {') or abort 'missing reaction controller'
finish=source.index('workspace_navigation::Gesture navigationGesture;',start) or abort 'missing controller end'
functions=source[start...finish]
abort 'Home still requests speech' if source.include?('requestRobotSpeech(')
fixture=<<~CPP
  #include <cassert>
  #include <initializer_list>
  #include "RobotHomeInteraction.h"
  unsigned now=100;unsigned millis(){return now;}
  robot_home::Animation robotAnimation;
  #{functions}
  int main(){
    requestRobotReaction();
    assert(robotAnimation.mood(now)==robot_home::Mood::Blink);
    for (unsigned elapsed=0; elapsed<1320; ++elapsed) {
      now=100+elapsed;requestRobotReaction(); // also retap during open gaps
      assert(robotAnimation.elapsed(now)==elapsed);
      assert(robotAnimation.mood(now)==robot_home::Mood::Blink);
      updateRobotReaction(true);
    }
    now=1420;assert(robotAnimation.mood(now)==robot_home::Mood::Idle);
    now=1900;updateRobotReaction(true);
    assert(robotAnimation.mood(now)==robot_home::Mood::Idle); // no queued fourth blink
    for (unsigned elapsed : {0u, 360u, 480u, 840u, 960u, 1319u}) {
      now=0xfffffff0u;requestRobotReaction();
      now+=elapsed;
      updateRobotReaction(false); // leave, sleep, power overlay at any phase
      assert(robotAnimation.mood(now)==robot_home::Mood::Idle);
      now+=2000;updateRobotReaction(true);
      assert(robotAnimation.mood(now)==robot_home::Mood::Idle);
    }
  }
CPP
Dir.mktmpdir('robot-blink-reaction-','/private/tmp') do |dir|
  file=File.join(dir,'test.cpp');File.write(file,fixture)
  abort 'compile failed' unless system('clang++','-std=c++17',"-I#{repo}/include",file,'-o',File.join(dir,'test'))
  abort 'reaction regression failed' unless system(File.join(dir,'test'))
end
puts 'PASS actual Home reaction: silent blink, no audio dependency, no overlap, cancellation'
