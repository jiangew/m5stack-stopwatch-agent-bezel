# Exercise the actual firmware gesture function with hardware-boundary doubles.
require 'tmpdir'
repo = File.expand_path('..', __dir__)
source = File.read(File.join(repo, 'src/main.cpp'))
start = source.index('void updateTouchGesture(int x, int y) {') or abort 'missing gesture function'
finish = source.index('void finishTouchGesture(', start) or abort 'missing next function'
function = source[start...finish]
fixture = <<~CPP
  #include <cassert>
  #include "RobotHomeInteraction.h"
  #include "WorkspaceInputPolicy.h"
  using touch_gesture::Direction;
  struct { workspace_mode::Mode workspaceMode=workspace_mode::Mode::Home; bool workspaceHostReady=true; } state;
  struct TapStub { void move(int,int,int){} void cancel(){} } workspaceCenterTap;
  robot_home::Tap robotTap;
  robot_home::Animation robotAnimation;
  bool touchTracking=true,touchPowerHoldConsumed=false,awake=true;
  Direction activeSwipe=Direction::None;
  int touchStartX=200,touchStartY=200;
  constexpr int kSwipeThresholdPx=52;
  constexpr int kSwipeHapticIntensity=77,kSwipeHapticDurationMs=88;
  constexpr int kButtonHapticIntensity=11,kWakeHapticDurationMs=22;
  int sent=0,haptics=0,intensity=0,duration=0;
  unsigned millis(){return 100;}
  unsigned esp_random(){return 1;}
  bool directionalWorkspaceActive(){return state.workspaceMode!=workspace_mode::Mode::Codex;}
  workspace_input::Control controlForSwipe(Direction){return workspace_input::Control::SwipeLeft;}
  bool noteActivity(){bool was=awake;awake=true;return was;}
  void clearTouchCandidate(){robotTap.cancel();}
  void sendSwipePress(Direction d){assert(d==Direction::Left);++sent;}
  void startHaptic(int i,int d){++haptics;intensity=i;duration=d;}
  void drawScreen(){}
  struct {template<class F>void acceptSwipe(unsigned,F){}} workspacePalette;
  struct {template<class... A>void printf(const char*,A...){}} Serial;
  #{function}
  void reset(){sent=haptics=0;touchTracking=true;awake=true;activeSwipe=Direction::None;state.workspaceHostReady=true;}
  int main(){
    reset();updateTouchGesture(140,200);
    assert(sent==1&&haptics==1);
    assert(intensity==kSwipeHapticIntensity&&duration==kSwipeHapticDurationMs);
    updateTouchGesture(130,200);assert(sent==1&&haptics==1);
    reset();state.workspaceHostReady=false;updateTouchGesture(140,200);
    assert(sent==0&&haptics==0&&robotAnimation.mood(100)==robot_home::Mood::Connect);
    reset();updateTouchGesture(200,140);assert(sent==0&&haptics==0);
    reset();updateTouchGesture(200,260);assert(sent==0&&haptics==0);
    reset();updateTouchGesture(260,200);assert(sent==0&&haptics==0);
    reset();updateTouchGesture(201,200);assert(sent==0&&haptics==0);
    reset();awake=false;updateTouchGesture(140,200);
    assert(sent==0&&haptics==1&&duration==kWakeHapticDurationMs&&!touchTracking);
  }
CPP
Dir.mktmpdir('robot-home-swipe-', '/private/tmp') do |dir|
  file=File.join(dir,'test.cpp');File.write(file,fixture)
  args=['clang++','-std=c++17','-DCODEX_STOPWATCH_USB_MIC',"-I#{repo}/include",
        "-I#{repo}/usb-mic/.pio/libdeps/m5stack-stopwatch-usb-mic/ArduinoJson/src",file,'-o',File.join(dir,'test')]
  abort 'compile failed' unless system(*args)
  abort 'gesture regression failed' unless system(File.join(dir,'test'))
end
puts 'PASS actual Home gesture: haptic, repeat, offline, local reactions, wake'
