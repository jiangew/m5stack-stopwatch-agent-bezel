# Compile the production audio-owner routine with hardware-only doubles.
require 'tmpdir'
repo = File.expand_path('..', __dir__)
source = File.read(File.join(repo, 'src/UsbMic.cpp'))
start = source.index('bool performCompletionChime(size_t* nextBuffer) {') or abort 'missing audio owner'
finish = source.index('void captureAudio(', start) or abort 'missing capture task'
function = source[start...finish]
fixture = <<~CPP
  #include <cassert>
  #include <array>
  #include <atomic>
  #include "UsbMic.h"
  #include "RobotSpeechData.h"
  using namespace stopwatch_usb_mic;
  enum class ChimePhase {Idle, Playing};
  std::atomic<ChimePhase> chimePhase{ChimePhase::Idle};
  std::atomic<bool> captureHardwareReady{true};
  std::atomic<LocalSound> selectedSound{LocalSound::RobotTask};
  std::atomic<bool> speechCancelled{false};
  unsigned clockMs=0, interruptAt=999999, cancelAt=999999;
  bool streaming=false, micRestore=true, speakerBegin=true;
  int restores=0, queued=0, captureQueues=0;
  ChimeResult terminal=ChimeResult::NeverRequested;
  constexpr unsigned kChimeVolume=160,kChimeSampleRate=12000,kChimePlaybackTimeoutMs=500,kChimeDmaDrainMs=48;
  std::array<short,3240> completionChimePcm{};
  const short* playedData=nullptr; unsigned playedRate=0; size_t playedCount=0;
  unsigned millis(){return clockMs;}
  void vTaskDelay(unsigned n){clockMs+=n;if(clockMs>=interruptAt)streaming=true;if(clockMs>=cancelAt)speechCancelled=true;}
  unsigned pdMS_TO_TICKS(unsigned n){return n;}
  struct Speaker {
    bool enabled=false;unsigned ends=0;
    bool begin(){enabled=speakerBegin;return enabled;}
    bool isRunning(){return enabled;}
    void setVolume(int){}
    bool playRaw(const short* p,size_t n,unsigned rate,bool,int,int,bool){
      ++queued;playedData=p;playedCount=n;playedRate=rate;ends=clockMs+(n*1000/rate);return true;
    }
    bool isPlaying(){return enabled&&clockMs<ends;}
  };
  struct Mic {int isRecording(){return 0;}void end(){}};
  struct {Speaker Speaker;Mic Mic;} M5;
  void noteChimeCapturePause(){}
  bool streamRequestedDuringChime(){return streaming;}
  bool localSoundInterrupted(){return streaming||speechCancelled.load();}
  ChimeResult interruptionResult(bool played){return streaming?(played?ChimeResult::AbortedStreaming:ChimeResult::SkippedStreaming):ChimeResult::Cancelled;}
  void finishChime(ChimeResult r){terminal=r;}
  bool queueInitialCaptureBlocks(size_t*){++captureQueues;return micRestore;}
  bool restartCaptureAfterChime(size_t*){++restores;return micRestore;}
  void setAudioPower(bool){} void setSpeakerAmp(bool){}
  bool configureCodecSpeaker(){return true;}
  void stopLocalSpeaker(){M5.Speaker.enabled=false;}
  #{function}
  void reset(){clockMs=0;interruptAt=cancelAt=999999;streaming=false;speechCancelled=false;micRestore=speakerBegin=true;restores=queued=captureQueues=0;M5.Speaker={};terminal=ChimeResult::NeverRequested;}
  int main(){size_t next=0;
    reset();selectedSound=LocalSound::RobotTask;assert(performCompletionChime(&next));
    assert(terminal==ChimeResult::Played&&playedRate==24000&&playedCount==84372&&restores==1);
    assert(playedData==robot_speech::kTask);
    reset();selectedSound=LocalSound::RobotLaugh;assert(performCompletionChime(&next));
    assert(terminal==ChimeResult::Played&&playedCount==50200&&playedData==robot_speech::kLaugh);
    reset();selectedSound=LocalSound::Completion;assert(performCompletionChime(&next));
    assert(terminal==ChimeResult::Played&&playedRate==12000&&playedCount==3240);
    reset();selectedSound=LocalSound::RobotTask;streaming=true;assert(performCompletionChime(&next));
    assert(queued==0&&captureQueues==1&&terminal==ChimeResult::SkippedStreaming);
    reset();interruptAt=100;assert(performCompletionChime(&next));
    assert(terminal==ChimeResult::AbortedStreaming&&restores==1&&clockMs<150);
    reset();speechCancelled=true;assert(performCompletionChime(&next));
    assert(queued==0&&terminal==ChimeResult::Cancelled);
    reset();cancelAt=100;assert(performCompletionChime(&next));
    assert(terminal==ChimeResult::Cancelled&&restores==1&&clockMs<150);
    reset();cancelAt=10;assert(performCompletionChime(&next));
    assert(queued==0&&terminal==ChimeResult::Cancelled&&restores==1);
    reset();interruptAt=10;assert(performCompletionChime(&next));
    assert(queued==0&&terminal==ChimeResult::SkippedStreaming&&restores==1);
    reset();cancelAt=3530;assert(performCompletionChime(&next));
    assert(terminal==ChimeResult::Cancelled&&restores==1); // DMA drain remains cancellable
    reset();speakerBegin=false;assert(performCompletionChime(&next));
    assert(terminal==ChimeResult::SpeakerStartFailed&&restores==1);
    reset();micRestore=false;assert(!performCompletionChime(&next));
    assert(terminal==ChimeResult::MicrophoneRestoreFailed);
  }
CPP
Dir.mktmpdir('robot-speech-audio-', '/private/tmp') do |dir|
  # Synthetic silence tests timing and routing without carrying voice samples.
  File.write(File.join(dir,'RobotSpeechData.h'), "#include <cstdint>\nnamespace robot_speech { constexpr unsigned kSampleRate=24000; constexpr std::int16_t kTask[84372]={}; constexpr std::int16_t kLaugh[50200]={}; }\n")
  file=File.join(dir,'test.cpp');File.write(file,fixture)
  abort 'compile failed' unless system('clang++','-std=c++17',"-I#{repo}/include",file,'-o',File.join(dir,'test'))
  abort 'audio owner regression failed' unless system(File.join(dir,'test'))
end
puts 'PASS actual audio owner: clips, mic priority, cancellation, restoration'
