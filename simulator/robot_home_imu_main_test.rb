# Compile the actual main-loop IMU adapter, replacing only hardware boundaries.
require 'tmpdir'
repo=File.expand_path('..',__dir__)
source=File.read(File.join(repo,'src/main.cpp'))
def extract(source,signature)
  first=source.index(signature) or abort "missing #{signature}"
  body=source.index('{',first);depth=1;last=body+1
  while depth>0
    depth+=1 if source[last]=='{'
    depth-=1 if source[last]=='}'
    last+=1
  end
  source[first...last]
end
selection_first=source.index('  bool imuFrameDue=false;') or abort 'missing IMU frame selection'
selection_last=source.index(';',source.index('  const bool robotFrame=',selection_first))+1
selection=source[selection_first...selection_last]
draw=extract(source,'void drawScreen() {')
presentation=extract(draw[draw.index('  lastDrawMs = millis();')..],'if (state.workspaceMode == workspace_mode::Mode::Home) {')
fixture=<<~CPP
  #include <cassert>
  #include <cmath>
  #include <algorithm>
  #define CODEX_STOPWATCH_HOME_IMU 1
  #define CODEX_STOPWATCH_USB_MIC 1
  #include "RobotHomeFrame.h"
  #include "RobotHomeImuTelemetry.h"
  #include "RobotHomeInteraction.h"
  #include "PowerButtonGesture.h"
  namespace workspace_mode {enum class Mode {Home,Codex};}
  namespace dashboard {enum class PowerOverlay {None,Hold};}
  namespace m5 {struct IMU_Class {enum {sensor_mask_accel=1,sensor_mask_gyro=2};};}
  unsigned now=100,cpuUs=0,lastActivityMs=0;unsigned millis(){return now;}unsigned micros(){return cpuUs;}
  struct {workspace_mode::Mode workspaceMode=workspace_mode::Mode::Home;} state;
  dashboard::PowerOverlay powerOverlay=dashboard::PowerOverlay::None;
  bool deskSleeping=false,touchTracking=false,hapticActive=false,powerButtonPressed=false;
  constexpr unsigned char kActiveBrightness=128;
  unsigned char appliedBrightness=kActiveBrightness;
  bool displayRailOff=false,pendingPowerClickWokeDisplay=false;
  void delay(unsigned duration){now+=duration;}
  void setPanelRail(bool){}void setPanelReset(bool){}
  struct {void println(const char*){}} Serial;
  power_button_gesture::Detector powerButtonGesture(500);
  robot_home::imu::Detector robotImu;
  robot_home::imu::Pose robotImuPose,robotImuRenderedPose;
  robot_home::imu::Telemetry robotImuTelemetry;
  bool robotImuEnabled=true,robotImuWakeAllowed=false,robotImuEventPending=false,robotImuPosePending=false;
  bool robotImuComboPending=false,robotImuComboConsumed=false,robotImuQuiet=false,robotInputDirty=false;
  unsigned robotImuSampleAt=0,robotImuComboAt=0,robotImuQuietAt=0;
  std::uint64_t robotImuReadTotalUs=0;
  robot_home::Animation robotAnimation;
  robot_home::FrameClock robotFrames;
  struct {float transitionProgress(unsigned){return 1;}} robotCharacters;
  unsigned lastDrawMs=0;
  bool derivedStateChanged=false,shouldRedraw=false;
  struct Button {bool pressed=false;bool isPressed(){return pressed;}};
  struct Triple {float x=0,y=0,z=0;};
  struct Imu {
    bool available=true;unsigned mask=3;
    struct Data {Triple accel{0,0,1},gyro; } data;
    bool isEnabled(){return available;}
    unsigned update(){cpuUs+=100;return mask;}
    Data getImuData(){return data;}
  };
  struct Touch {bool pressed=false;Touch& getDetail(){return *this;}bool isPressed(){return pressed;}};
  struct Display {
    struct Panel {bool init(bool){return true;}} panel;
    Panel* getPanel(){return &panel;}
    void setRotation(int){}void setTextWrap(bool){}void setBrightness(unsigned char){}
  };
  struct {Button BtnA,BtnB;Imu Imu;Touch Touch;Display Display;} M5;
  struct {void setImuTelemetry(const robot_home::imu::Telemetry&) {}} codex;
  unsigned presentedFrames=0;
  void drawScreen(){
    if(deskSleeping)return;
    const auto homeFrameStartedMs=now;
    const bool homeFrameAnimated=robotAnimation.active(now);
    // Model only raster/transfer cost at the hardware boundary. Presentation
    // bookkeeping below, noteActivity and wakeDeskSleep are actual main code.
    now+=65;++presentedFrames;lastDrawMs=millis();
    #{presentation}
  }
  #{extract(source,'void wakeDeskSleep()')}
  #{extract(source,'bool noteActivity()')}
  #{extract(source,'bool imuPoseChanged(')}
  #{extract(source,'void updateRobotImu()')}
  bool frameDue(unsigned robotNow,bool homeVisible=true) {
    #{selection}
    return robotFrame;
  }
  void feed(robot_home::imu::Sample s={},unsigned duration=20) {
    M5.Imu.data.accel={s.ax,s.ay,s.az};M5.Imu.data.gyro={s.gx,s.gy,s.gz};
    for(unsigned i=0;i<duration;i+=20){now+=20;updateRobotImu();}
  }
  int main(){
    // Catch post-transfer waiting in the actual main-loop selection.
    robotFrames.presented(130,false);lastDrawMs=195;
    robotImuPose.angle=1;
    assert(frameDue(200)); // 65ms rendering already consumed the cadence
    robotImuRenderedPose=robotImuPose;assert(!frameDue(201));
    robotFrames.presented(300,false);lastDrawMs=305;robotImuPose.angle=2;
    assert(!frameDue(333));assert(frameDue(334));
    robotFrames.presented(0xfffffff0u,false);lastDrawMs=0xfffffff5u;
    assert(!frameDue(17));assert(frameDue(18));
    assert(!frameDue(19,false)); // hidden Home does not render
    assert(frameDue(20)); // first visible frame after invalidation
    robotFrames.presented(400,false);robotImuRenderedPose=robotImuPose;
    robotInputDirty=true;assert(frameDue(401));robotInputDirty=false;
    derivedStateChanged=true;assert(frameDue(401));derivedStateChanged=false;
    shouldRedraw=true;assert(frameDue(401));shouldRedraw=false;
    robotFrames.presented(400,true);assert(frameDue(401)); // final animation frame
    robotImuPose={};robotImuRenderedPose={};

    feed({},1600);assert(robotImuTelemetry.phase==robot_home::imu::Phase::Resting);
    auto resting=robotImuPose;
    M5.BtnA.pressed=true;feed({},100); // physical chord edges are staggered
    M5.BtnB.pressed=true;feed({},2100);
    assert(!robotImuEnabled&&!imuPoseChanged(robotImuPose,resting));
    auto offSamples=robotImuTelemetry.samples;
    feed({},2200);assert(!robotImuEnabled&&robotImuTelemetry.samples==offSamples);
    M5.BtnA.pressed=M5.BtnB.pressed=false;feed({},400);
    assert(!imuPoseChanged(robotImuPose,resting));
    M5.BtnA.pressed=M5.BtnB.pressed=true;feed({},2100);
    assert(robotImuEnabled);
    M5.BtnA.pressed=M5.BtnB.pressed=false;feed({},2000);
    assert(robotImuTelemetry.phase==robot_home::imu::Phase::Resting);
    // Home wake taps are consumed and do not set touchTracking. Still inhibit
    // physical touch and the full quiet interval after release.
    touchTracking=false;M5.Touch.pressed=true;
    auto beforeTouch=robotImuTelemetry.samples;
    feed({0,0,1.2f,0,0,0},200);
    assert(robotImuTelemetry.samples==beforeTouch&&robotImuTelemetry.pickups==0);
    M5.Touch.pressed=false;feed({},200);
    assert(robotImuTelemetry.samples==beforeTouch);
    feed({},1800);
    drawScreen();const auto framesBeforeAwakePickup=presentedFrames;
    feed({0,0,1.2f,0,0,0},80);
    assert(robotImuTelemetry.pickups==1&&presentedFrames==framesBeforeAwakePickup);
    assert(robotInputDirty&&frameDue(now)); // awake pickup still needs its frame
    drawScreen();assert(!robotInputDirty&&!frameDue(now));
    feed({},1800);assert(robotImuTelemetry.settles==1);
    state.workspaceMode=workspace_mode::Mode::Codex;auto previous=robotImuTelemetry.samples;
    feed({0,0,1.2f,30,0,0},200);assert(robotImuTelemetry.samples==previous&&robotImuTelemetry.pickups==1);
    state.workspaceMode=workspace_mode::Mode::Home;feed({},1800);
    deskSleeping=true;robotImuWakeAllowed=false;previous=robotImuTelemetry.samples;
    feed({0,0,1.2f,30,0,0},200);assert(robotImuTelemetry.samples==previous&&deskSleeping);
    deskSleeping=false;feed({},1800);deskSleeping=true;robotImuWakeAllowed=true;
    const auto framesBeforeWake=presentedFrames;
    feed({0,0,1.2f,0,0,0},80);
    assert(!deskSleeping&&robotImuTelemetry.pickups==2);
    assert(!robotImuEventPending&&robotImuTelemetry.eventFrameMs==65);
    if(frameDue(now))drawScreen(); // execute actual outer selection after wake
    assert(presentedFrames==framesBeforeWake+1&&"pickup wake must present only one frame");
    assert(!robotInputDirty&&!imuPoseChanged(robotImuPose,robotImuRenderedPose));
    now+=8; // existing main-loop delay after the one synchronous wake render
    M5.Imu.data.accel={0,.173648f,.984808f};M5.Imu.data.gyro={25,0,0};
    const auto wakeSampleGap=now-robotImuSampleAt;
    updateRobotImu();
    assert(wakeSampleGap==73&&robotImuTelemetry.phase==robot_home::imu::Phase::Held);
    assert(robotImuPose.angle>0&&robotImuPose.x>0&&frameDue(now));
    drawScreen();assert(!frameDue(now)); // continued tilt is presented once
    powerButtonGesture.release(now);previous=robotImuTelemetry.samples;
    feed({0,0,1.2f,30,0,0},100);assert(robotImuTelemetry.samples==previous);
    powerButtonGesture.cancel();powerOverlay=dashboard::PowerOverlay::Hold;
    feed({0,0,1.2f,30,0,0},200);assert(robotImuTelemetry.samples==previous);
    powerOverlay=dashboard::PowerOverlay::None;M5.Imu.available=false;
    feed({},200);assert(!robotImuTelemetry.available&&robotImuTelemetry.samples==previous);
  }
CPP
Dir.mktmpdir('home-imu-main-') do |dir|
  file=File.join(dir,'test.cpp');binary=File.join(dir,'test')
  File.write(file,fixture)
  system('clang++','-std=c++17','-I'+File.join(repo,'include'),file,'-o',binary) or abort 'compile failed'
  system(binary) or abort 'actual main IMU policy regression failed'
end
puts 'PASS actual IMU adapter: render-start cadence, unchanged/fast/wrapped/hidden frames, priority bypass; one 65ms synchronous pickup-wake frame, Held at next 73ms sample and positive tilt; awake pickup redraw; staggered A/B chord, swallowed physical touch, quiet interval, workspace/power boundaries and sensor availability'
