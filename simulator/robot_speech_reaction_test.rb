require 'tmpdir'
repo=File.expand_path('..',__dir__)
source=File.read(File.join(repo,'src/main.cpp'))
start=source.index('void stopRobotReaction() {') or abort 'missing reaction controller'
finish=source.index('workspace_navigation::Gesture navigationGesture;',start) or abort 'missing controller end'
functions=source[start...finish]
fixture=<<~CPP
  #include <cassert>
  #include "UsbMic.h"
  #include "RobotHomeInteraction.h"
  using namespace stopwatch_usb_mic;
  unsigned now=100;unsigned millis(){return now;}
  robot_home::Animation robotAnimation;
  bool robotSpeechTracked=false;unsigned robotSpeechSequence=0;
  int requests=0,cancels=0;
  ChimeStatus audio{};
  ChimeRequestResult disposition=ChimeRequestResult::Queued;
  namespace stopwatch_usb_mic {
  void cancelRobotSpeech(){++cancels;}
  ChimeStatus snapshotChimeStatus(){return audio;}
  ChimeRequestResult requestRobotSpeech(LocalSound){++requests;audio.sequence++;audio.pending=disposition==ChimeRequestResult::Queued;return disposition;}
  }
  #{functions}
  int main(){
    requestRobotReaction(LocalSound::RobotTask);
    assert(requests==1&&robotSpeechTracked&&robotAnimation.mood(now)==robot_home::Mood::Talking);
    now+=1000;requestRobotReaction(LocalSound::RobotLaugh);assert(requests==1);
    updateRobotReaction(true);assert(robotAnimation.mood(now)==robot_home::Mood::Talking);
    audio.pending=false;updateRobotReaction(true);assert(robotAnimation.mood(now)==robot_home::Mood::Idle);
    disposition=ChimeRequestResult::SkippedStreaming;
    requestRobotReaction(LocalSound::RobotLaugh);assert(!robotSpeechTracked&&requests==2);
    assert(robotAnimation.mood(now+1199)==robot_home::Mood::Talking);
    assert(robotAnimation.mood(now+1200)==robot_home::Mood::Idle);
    requestRobotReaction(LocalSound::RobotLaugh);assert(requests==2); // silent response also debounced
    updateRobotReaction(false);assert(cancels==1&&robotAnimation.mood(now)==robot_home::Mood::Idle);
    disposition=ChimeRequestResult::Queued;requestRobotReaction(LocalSound::RobotLaugh);
    ++audio.sequence;updateRobotReaction(true);assert(!robotSpeechTracked); // unrelated later sound cannot prolong it
    audio.pending=true;requestRobotReaction(LocalSound::RobotTask);assert(requests==3);
  }
CPP
Dir.mktmpdir('robot-speech-reaction-','/private/tmp') do |dir|
  file=File.join(dir,'test.cpp');File.write(file,fixture)
  abort 'compile failed' unless system('clang++','-std=c++17',"-I#{repo}/include",file,'-o',File.join(dir,'test'))
  abort 'reaction regression failed' unless system(File.join(dir,'test'))
end
puts 'PASS actual reaction controller: no overlap, shared animation, status completion, silent fallback'
