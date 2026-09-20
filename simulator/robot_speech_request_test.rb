require 'tmpdir'
repo=File.expand_path('..',__dir__)
source=File.read(File.join(repo,'src/UsbMic.cpp'))
start=source.index('static ChimeRequestResult requestLocalSound(') or abort 'missing request function'
finish=source.index('ChimeStatus snapshotChimeStatus()',start) or abort 'missing snapshot'
functions=source[start...finish]
fixture=<<~CPP
  #include <cassert>
  #include <atomic>
  #include "UsbMic.h"
  using namespace stopwatch_usb_mic;
  namespace robot_speech { bool kAvailable=true; }
  enum class ChimePhase {Idle, Arming, Guarding, Playing};
  std::atomic<ChimePhase> chimePhase{ChimePhase::Idle};
  std::atomic<LocalSound> selectedSound{LocalSound::Completion};
  std::atomic<bool> speechCancelled{false},pipelineStarted{true},captureHardwareReady{true};
  std::atomic<unsigned> micInterfaceEnableGeneration{0},chimeAlt1Baseline{0},chimeGuardUntilMs{0};
  bool streaming=false,pulseWhileArming=false;
  int requests=0,busy=0,queued=0;
  ChimeResult terminal=ChimeResult::NeverRequested;
  constexpr unsigned kChimeIdleGuardMs=200;
  unsigned millis(){return 100;}
  void noteChimeRequest(){++requests;}
  void noteChimeBusy(){++busy;}
  bool streamRequestedDuringChime(){return streaming||micInterfaceEnableGeneration!=chimeAlt1Baseline;}
  void armChimeStatus(bool q){if(q)++queued;if(pulseWhileArming)++micInterfaceEnableGeneration;}
  void finishChime(ChimeResult r){terminal=r;chimePhase=ChimePhase::Idle;}
  bool finishGuardingChime(ChimeResult r){finishChime(r);return true;}
  namespace stopwatch_usb_mic {
  #{functions}
  }
  void reset(){chimePhase=ChimePhase::Idle;pipelineStarted=captureHardwareReady=true;streaming=pulseWhileArming=false;requests=busy=queued=0;micInterfaceEnableGeneration=chimeAlt1Baseline=0;}
  int main(){
    robot_speech::kAvailable=false;
    assert(requestRobotSpeech(LocalSound::RobotTask)==ChimeRequestResult::Unavailable&&requests==0);
    robot_speech::kAvailable=true;
    reset();assert(requestRobotSpeech(LocalSound::RobotTask)==ChimeRequestResult::Queued);
    assert(selectedSound==LocalSound::RobotTask&&chimePhase==ChimePhase::Guarding&&queued==1);
    cancelRobotSpeech();assert(speechCancelled);
    assert(requestRobotSpeech(LocalSound::RobotLaugh)==ChimeRequestResult::Busy);
    assert(selectedSound==LocalSound::RobotTask&&speechCancelled&&queued==1);
    reset();streaming=true;assert(requestRobotSpeech(LocalSound::RobotLaugh)==ChimeRequestResult::SkippedStreaming);
    assert(chimePhase==ChimePhase::Idle&&queued==0);
    reset();pulseWhileArming=true;
    assert(requestRobotSpeech(LocalSound::RobotTask)==ChimeRequestResult::SkippedStreaming);
    assert(chimePhase==ChimePhase::Idle); // even an alt1 -> alt0 pulse wins
    reset();assert(requestCompletionChime()==ChimeRequestResult::Queued);
    cancelRobotSpeech();assert(!speechCancelled); // never cancel a completion chime
    reset();assert(requestRobotSpeech(LocalSound::Completion)==ChimeRequestResult::Unsupported&&requests==0);
    assert(requestRobotSpeech(static_cast<LocalSound>(255))==ChimeRequestResult::Unsupported&&requests==0);
    reset();captureHardwareReady=false;
    assert(requestRobotSpeech(LocalSound::RobotTask)==ChimeRequestResult::Unavailable&&queued==0);
  }
CPP
Dir.mktmpdir('robot-speech-request-','/private/tmp') do |dir|
  file=File.join(dir,'test.cpp');File.write(file,fixture)
  abort 'compile failed' unless system('clang++','-std=c++17',"-I#{repo}/include",file,'-o',File.join(dir,'test'))
  abort 'request regression failed' unless system(File.join(dir,'test'))
end
puts 'PASS actual requests: busy, cancel, stream priority, invalid clips, no retry'
