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
fixture=<<~CPP
  #include <cassert>
  #include <cmath>
  #include <algorithm>
  #define CODEX_STOPWATCH_HOME_IMU 1
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
  unsigned char appliedBrightness=128;
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
  struct {Button BtnA,BtnB;Imu Imu;Touch Touch;} M5;
  struct {void setImuTelemetry(const robot_home::imu::Telemetry&) {}} codex;
  unsigned wakes=0;bool noteActivity(){++wakes;deskSleeping=false;lastActivityMs=now;return true;}
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
    feed({0,0,1.2f,0,0,0},80);
    assert(robotImuTelemetry.pickups==1&&wakes==1);
    feed({},1800);assert(robotImuTelemetry.settles==1);
    state.workspaceMode=workspace_mode::Mode::Codex;auto previous=robotImuTelemetry.samples;
    feed({0,0,1.2f,30,0,0},200);assert(robotImuTelemetry.samples==previous&&wakes==1);
    state.workspaceMode=workspace_mode::Mode::Home;feed({},1800);
    deskSleeping=true;robotImuWakeAllowed=false;previous=robotImuTelemetry.samples;
    feed({0,0,1.2f,30,0,0},200);assert(robotImuTelemetry.samples==previous&&deskSleeping);
    deskSleeping=false;feed({},1800);deskSleeping=true;robotImuWakeAllowed=true;
    feed({0,0,1.2f,0,0,0},80);assert(!deskSleeping&&wakes==2);
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
puts 'PASS actual IMU adapter: render-start cadence, unchanged/fast/wrapped/hidden frames, priority bypass; staggered A/B chord, swallowed physical touch, quiet interval, workspace/power boundaries and sensor availability'
