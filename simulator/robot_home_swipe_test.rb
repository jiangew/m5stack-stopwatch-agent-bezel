# Exercise the actual firmware gesture function with hardware-boundary doubles.
require 'tmpdir'
repo = File.expand_path('..', __dir__)
source = File.read(File.join(repo, 'src/main.cpp'))
start = source.index('void updateTouchGesture(int x, int y) {') or abort 'missing gesture function'
finish = source.index('void finishTouchGesture(', start) or abort 'missing next function'
function = source[start...finish]
fixture = <<~CPP
  #include <cassert>
  #include <utility>
  #include <initializer_list>
  #include "RobotHomeCharacter.h"
  #include "RobotHomeInteraction.h"
  #include "WorkspaceInputPolicy.h"
  #include "UsbMic.h"
  using touch_gesture::Direction;
  struct { workspace_mode::Mode workspaceMode=workspace_mode::Mode::Home; bool workspaceHostReady=true; } state;
  struct TapStub { void move(int,int,int){} void cancel(){} } workspaceCenterTap;
  robot_home::Tap robotTap;
  robot_home::Animation robotAnimation;
  robot_home::CharacterSelector robotCharacters;
  bool touchTracking=true,touchPowerHoldConsumed=false,awake=true;
  Direction activeSwipe=Direction::None;
  int touchStartX=200,touchStartY=200;
  constexpr int kSwipeThresholdPx=52;
  constexpr int kSwipeHapticIntensity=77,kSwipeHapticDurationMs=88;
  constexpr int kButtonHapticIntensity=11,kWakeHapticDurationMs=22;
  int sent=0,haptics=0,intensity=0,duration=0;
  int speech=0,cancels=0;
  void requestRobotReaction(){++speech;robotAnimation.press(100);robotAnimation.release(100);}
  void stopRobotReaction(){++cancels;}
  unsigned millis(){return 100;}
  unsigned entropy=0,entropyCalls=0;
  unsigned esp_random(){++entropyCalls;return entropy;}
  bool directionalWorkspaceActive(){return state.workspaceMode!=workspace_mode::Mode::Codex;}
  workspace_input::Control controlForSwipe(Direction d){
    switch(d){
      case Direction::Up:return workspace_input::Control::SwipeUp;
      case Direction::Down:return workspace_input::Control::SwipeDown;
      case Direction::Right:return workspace_input::Control::SwipeRight;
      default:return workspace_input::Control::SwipeLeft;
    }
  }
  bool noteActivity(){bool was=awake;awake=true;return was;}
  void clearTouchCandidate(){robotTap.cancel();}
  void sendSwipePress(Direction d){assert(d!=Direction::None);++sent;}
  void startHaptic(int i,int d){++haptics;intensity=i;duration=d;}
  void drawScreen(){}
  int recolors=0;
  struct {template<class F>void acceptSwipe(unsigned,F){++recolors;}} workspacePalette;
  struct {template<class... A>void printf(const char*,A...){}} Serial;
  #{function}
  void reset(bool resetCharacter=true){sent=haptics=speech=cancels=entropyCalls=0;touchTracking=true;awake=true;activeSwipe=Direction::None;state.workspaceHostReady=true;if(resetCharacter)robotCharacters.reset();}
  int main(){
    reset();updateTouchGesture(140,200);
    assert(sent==1&&haptics==1&&speech==0&&cancels==1);
    assert(intensity==kSwipeHapticIntensity&&duration==kSwipeHapticDurationMs);
    updateTouchGesture(130,200);assert(sent==1&&haptics==1);
    reset();state.workspaceHostReady=false;updateTouchGesture(140,200);
    assert(sent==0&&haptics==0&&robotAnimation.mood(100)==robot_home::Mood::Connect);
    // Literal outcomes catch wrong faction routing and accidental right entropy.
    const std::pair<int,int> local[]{ {200,140},{200,260},{260,200} };
    const unsigned first[]{1,9,0}, repeated[]{2,10,0};
    for(unsigned direction=0;direction<3;++direction){
      const auto xy=local[direction];
      for(bool ready:{false,true}){
        reset();entropy=0;state.workspaceHostReady=ready;updateTouchGesture(xy.first,xy.second);
        assert(static_cast<unsigned>(robotCharacters.character())==first[direction]);
        assert(sent==0&&speech==0&&cancels==1&&haptics==1);
        assert(entropyCalls==(direction==2?0u:1u));
        assert(activeSwipe==Direction::None&&!touchTracking);
        assert(intensity==kSwipeHapticIntensity&&duration==kSwipeHapticDurationMs);
        updateTouchGesture(xy.first,xy.second);assert(haptics==1&&cancels==1);
        reset(false);state.workspaceHostReady=ready;updateTouchGesture(xy.first,xy.second);
        assert(static_cast<unsigned>(robotCharacters.character())==repeated[direction]);
        assert(sent==0&&speech==0&&haptics==1&&entropyCalls==(direction==2?0u:1u));
        reset(false);awake=false;updateTouchGesture(xy.first,xy.second);
        assert(static_cast<unsigned>(robotCharacters.character())==repeated[direction]);
        assert(sent==0&&haptics==1&&duration==kWakeHapticDurationMs&&!touchTracking&&entropyCalls==0);
      }
    }
    // Exercise every pool member through actual updateTouchGesture, then return
    // each of the 16 bodies to the portrait with one tick and no host/entropy.
    for(unsigned direction=0;direction<2;++direction){
      for(unsigned sample=0;sample<8;++sample){
        reset();entropy=sample;updateTouchGesture(local[direction].first,local[direction].second);
        assert(static_cast<unsigned>(robotCharacters.character())==sample+(direction==0?1:9));
        assert(sent==0&&speech==0&&haptics==1&&entropyCalls==1);
        reset(false);updateTouchGesture(260,200);
        assert(robotCharacters.character()==robot_home::Character::Bumblebee);
        assert(sent==0&&speech==0&&haptics==1&&entropyCalls==0);
      }
    }
    entropy=0;
    reset();updateTouchGesture(201,200);assert(sent==0&&haptics==0);
    reset();awake=false;updateTouchGesture(140,200);
    assert(sent==0&&haptics==1&&duration==kWakeHapticDurationMs&&!touchTracking&&speech==0);
    state.workspaceMode=workspace_mode::Mode::Deepseek;
    for(const auto xy : {std::pair<int,int>{200,140},{200,260},{260,200}}){
      reset();recolors=0;updateTouchGesture(xy.first,xy.second);
      assert(sent==1&&haptics==1&&recolors==1&&speech==0);
      updateTouchGesture(xy.first,xy.second);assert(sent==1);
      reset();awake=false;recolors=0;updateTouchGesture(xy.first,xy.second);
      assert(sent==0&&recolors==0&&!touchTracking&&duration==kWakeHapticDurationMs);
    }
    reset();recolors=0;updateTouchGesture(140,200);
    assert(sent==1&&haptics==1); // left remains the workspace cycle
    for(auto mode:{workspace_mode::Mode::CodexIdle,workspace_mode::Mode::CodexOpening,workspace_mode::Mode::CodexError,
        workspace_mode::Mode::DeepseekIdle,workspace_mode::Mode::DeepseekOpening,workspace_mode::Mode::DeepseekError,
        workspace_mode::Mode::SuperIdle,workspace_mode::Mode::SuperOpening,workspace_mode::Mode::SuperError,
        workspace_mode::Mode::HermesIdle,workspace_mode::Mode::HermesOpening,workspace_mode::Mode::HermesError}){
      state.workspaceMode=mode;
      for(const auto xy:{std::pair<int,int>{200,140},{200,260},{260,200}}){
        reset();recolors=0;updateTouchGesture(xy.first,xy.second);
        assert(sent==0&&haptics==0&&recolors==0);
      }
      reset();recolors=0;updateTouchGesture(140,200);
      assert(sent==1&&haptics==1&&recolors==1);
      reset();awake=false;updateTouchGesture(140,200);
      assert(sent==0&&!touchTracking&&duration==kWakeHapticDurationMs);
    }
  }
CPP
Dir.mktmpdir('robot-home-swipe-', '/private/tmp') do |dir|
  file=File.join(dir,'test.cpp');File.write(file,fixture)
  args=['clang++','-std=c++17','-DCODEX_STOPWATCH_USB_MIC',"-I#{repo}/include",
        "-I#{repo}/usb-mic/.pio/libdeps/m5stack-stopwatch-usb-mic/ArduinoJson/src",file,'-o',File.join(dir,'test')]
  abort 'compile failed' unless system(*args)
  abort 'gesture regression failed' unless system(File.join(dir,'test'))
end
puts 'PASS actual Home gesture: haptic, character selection, offline, wake'
