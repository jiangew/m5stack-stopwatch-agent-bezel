# Actual touch and IMU functions; only hardware, host transport and raster are doubles.
# Catches loss of calibrated phase at press/quiet, stale resume grants, inherited
# motion timers, invalid sample bypass, and extra 65ms renders after selection.
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
globals=source[source.index('robot_home::imu::Detector robotImu;')...source.index('#endif',source.index('robot_home::imu::Detector robotImu;'))]
selection_first=source.index('  bool imuFrameDue=false;')
selection_last=source.index(';',source.index('  const bool robotFrame=',selection_first))+1
selection=source[selection_first...selection_last]
draw=extract(source,'void drawScreen() {')
presentation=extract(draw[draw.index('  lastDrawMs = millis();')..],'if (state.workspaceMode == workspace_mode::Mode::Home) {')
fixture=<<~CPP
  #include <cassert>
  #include <cmath>
  #include <algorithm>
  #include <initializer_list>
  #include <utility>
  #define CODEX_STOPWATCH_HOME_IMU 1
  #define CODEX_STOPWATCH_USB_MIC 1
  #include "RobotHomeFrame.h"
  #include "RobotHomeImuTelemetry.h"
  #include "RobotHomeCharacter.h"
  #include "RobotHomeInteraction.h"
  #include "WorkspaceCenterTap.h"
  #include "WorkspaceInputPolicy.h"
  #include "PowerButtonGesture.h"
  using robot_home::imu::Phase;
  using robot_home::imu::Sample;
  using touch_gesture::Direction;
  namespace dashboard {enum class PowerOverlay {None,Hold,HoldToPowerOff};bool sendAtPoint(int,int){return false;}}
  namespace m5 {struct IMU_Class {enum {sensor_mask_accel=1,sensor_mask_gyro=2};};}
  unsigned now=100,cpuUs=0,lastActivityMs=0;unsigned millis(){return now;}unsigned micros(){return cpuUs;}
  struct {workspace_mode::Mode workspaceMode=workspace_mode::Mode::Home;bool workspaceHostReady=true;} state;
  dashboard::PowerOverlay powerOverlay=dashboard::PowerOverlay::None;
  bool deskSleeping=false,touchTracking=false,hapticActive=false,powerButtonPressed=false,powerButtonWokeDisplay=false;
  constexpr unsigned char kActiveBrightness=128;
  unsigned char appliedBrightness=kActiveBrightness;
  bool displayRailOff=false,pendingPowerClickWokeDisplay=false,docked=false;
  constexpr bool kCutSharedRailInDeskSleep=false;
  void delay(unsigned duration){now+=duration;}
  void setPanelRail(bool){}void setPanelReset(bool){}
  struct {void println(const char*){}template<class... A>void printf(const char*,A...){}} Serial;
  power_button_gesture::Detector powerButtonGesture(500);
  #{globals}
  bool robotInputDirty=false;
  robot_home::Tap robotTap;
  robot_home::Animation robotAnimation;
  robot_home::FrameClock robotFrames;
  robot_home::CharacterSelector robotCharacters;
  workspace_input::CenterTap workspaceCenterTap;
  unsigned lastDrawMs=0,hapticUntilMs=0,entropy=0,touchSendStartedAtMs=0,lastPowerOverlayDrawMs=0;
  bool derivedStateChanged=false,shouldRedraw=false;
  bool touchPowerHoldCandidate=false,touchAgentPressed=false,touchSendPressed=false,touchPowerHoldConsumed=false;
  bool leftPressed=false,rightPressed=false,voiceClickReleasePending=false,voiceTapBannerVisible=false;
  int activeTouchAgent=-1,robotTouchX=0,robotTouchY=0,workspaceTouchEndX=0,workspaceTouchEndY=0;
  short touchStartX=0,touchStartY=0;
  Direction activeSwipe=Direction::None;
  constexpr int kSwipeThresholdPx=52,kSwipeHapticIntensity=77,kSwipeHapticDurationMs=40;
  constexpr int kButtonHapticIntensity=11,kWakeHapticDurationMs=22,kTouchHapticIntensity=11,kTouchHapticDurationMs=25;
  constexpr unsigned kPowerHoldPromptMs=2000,kTravelPowerOffMs=6000;
  constexpr int kButtonHapticDurationMs=30;
  constexpr const char* kLeftMicSwitch="left";constexpr const char* kVoiceChatCommandKey="voice";
  unsigned esp_random(){return entropy;}
  #{extract(source,'bool directionalWorkspaceActive()')}
  #{extract(source,'workspace_input::Control controlForSwipe(')}
  int agentAtPoint(int,int){return -1;}
  void beginTouchAgent(int){}void beginTouchSend(){}
  void commitTouchAgent(){}void commitTouchSend(){}
  unsigned sent=0;
  void sendSwipePress(Direction){++sent;}void sendSwipeRelease(){}
  struct {template<class F>void acceptSwipe(unsigned,F){}} workspacePalette;
  struct {void clear(){}} completionBanner;
  struct Button {bool pressed=false;bool isPressed(){return pressed;}};
  struct Triple {float x=0,y=0,z=0;};
  struct Imu {
    bool available=true;unsigned mask=3;
    struct Data {Triple accel{0,0,1},gyro;} data;
    bool isEnabled(){return available;}
    unsigned update(){cpuUs+=100;return mask;}
    Data getImuData(){return data;}
  };
  struct Touch {bool pressed=false;Touch& getDetail(){return *this;}bool isPressed(){return pressed;}};
  struct Display {
    struct Panel {bool init(bool){return true;}} panel;Panel* getPanel(){return &panel;}
    void setRotation(int){}void setTextWrap(bool){}void setBrightness(unsigned char){}void releaseBus(){}
  };
  struct Power {void setVibration(unsigned char){}};
  struct {Button BtnA,BtnB;Imu Imu;Touch Touch;Display Display;Power Power;} M5;
  struct {void setImuTelemetry(const robot_home::imu::Telemetry&){}void sendKey(const char*,int){}void sendOpenWorkspace(){}} codex;
  void drawScreen();
  #{extract(source,'void stopRobotReaction()')}
  #{extract(source,'void requestRobotReaction()')}
  #{extract(source,'void startHaptic(')}
  #{extract(source,'void stopHaptic() {')}
  #{extract(source,'void updateHaptic()')}
  #{extract(source,'void enterDeskSleep(')}
  #{extract(source,'void wakeDeskSleep()')}
  #{extract(source,'bool noteActivity()')}
  #{extract(source,'void clearTouchCandidate() {')}
  #{extract(source,'void beginTouchPowerHoldCandidate()')}
  #{extract(source,'void beginTouchGesture(int x, int y) {')}
  #{extract(source,'void updateTouchGesture(int x, int y) {')}
  #{extract(source,'void finishTouchGesture(int x, int y) {')}
  #{extract(source,'void handleWorkspaceModeTransition(')}
  void enterTravelPowerOff(){assert(false&&"unexpected power off");}
  #{extract(source,'void updateTouchPowerHold()')}
  #{extract(source,'void beginPowerButtonPress()')}
  #{extract(source,'void finishPowerButtonPress()')}
  #{extract(source,'bool imuPoseChanged(')}
  #{extract(source,'void updateRobotImu()')}
  unsigned presentedFrames=0;
  void drawScreen(){
    if(deskSleeping)return;
    const auto homeFrameStartedMs=now;
    const bool homeFrameAnimated=robotAnimation.active(now);
    now+=65;++presentedFrames;lastDrawMs=millis();
    #{presentation}
  }
  bool frameDue(){const auto robotNow=now;const bool homeVisible=!deskSleeping&&state.workspaceMode==workspace_mode::Mode::Home;
    #{selection}
    return robotFrame;
  }
  void sample(Sample s={},unsigned dt=20){
    now+=dt;M5.Imu.data.accel={s.ax,s.ay,s.az};M5.Imu.data.gyro={s.gx,s.gy,s.gz};updateRobotImu();updateHaptic();
  }
  void feed(Sample s={},unsigned duration=20){for(unsigned i=0;i<duration;i+=20)sample(s);}
  const Sample moving{0,0,1.2f,25,0,0},positive{0,.173648f,.984808f,25,0,0},negative{0,-.173648f,.984808f,-25,0,0};
  void calibrate(bool held=true){feed({},1600);assert(robotImuTelemetry.phase==Phase::Resting);if(held){feed(moving,80);assert(robotImuTelemetry.phase==Phase::Held);}}
  void begin(){M5.Touch.pressed=true;beginTouchGesture(200,200);}
  void swipe(Direction d=Direction::Up){int x=200,y=200;if(d==Direction::Up)y=140;if(d==Direction::Down)y=260;if(d==Direction::Right)x=260;if(d==Direction::Left)x=140;updateTouchGesture(x,y);}
  void release(){M5.Touch.pressed=false;finishTouchGesture(200,200);}
  void reset(){
    revokeRobotImuSwipeResume();
    now=100;cpuUs=0;robotImu={};robotImuTelemetry={};robotImuPose={};robotImuRenderedPose={};
    robotImuEnabled=true;robotImuWakeAllowed=robotImuEventPending=robotImuPosePending=false;
    robotImuQuiet=robotImuComboPending=robotImuComboConsumed=false;
    robotImuSampleAt=robotImuQuietAt=robotImuComboAt=0;robotImuReadTotalUs=0;
    M5.Imu={};M5.Touch.pressed=M5.BtnA.pressed=M5.BtnB.pressed=false;
    state.workspaceMode=workspace_mode::Mode::Home;state.workspaceHostReady=true;
    powerOverlay=dashboard::PowerOverlay::None;powerButtonGesture.cancel();powerButtonPressed=false;
    touchTracking=touchPowerHoldConsumed=hapticActive=deskSleeping=false;appliedBrightness=kActiveBrightness;
    robotCharacters.reset();robotAnimation.cancel();robotTap.cancel();workspaceCenterTap.cancel();
    activeSwipe=Direction::None;robotFrames={};robotInputDirty=false;presentedFrames=sent=0;
  }
  void selectedPause(Direction direction=Direction::Up){begin();feed(moving,100);swipe(direction);feed(moving,100);}
  void quietResume(Sample s=positive){release();feed(s,280);}
  void expectCalibration(){assert(robotImuTelemetry.phase==Phase::Calibrating);assert(robotImuPose.angle==0&&robotImuPose.x==0);}
  int main(){
    calibrate();const auto samplesBeforeTouch=robotImuTelemetry.samples,pickupsBeforeTouch=robotImuTelemetry.pickups;
    begin();feed(moving,100);swipe();feed(moving,300);
    assert(robotImuTelemetry.samples==samplesBeforeTouch);
    release();feed(positive,240);assert(robotImuTelemetry.samples==samplesBeforeTouch);
    feed(positive,40);
    assert(robotImuTelemetry.pickups==pickupsBeforeTouch);
    assert(robotImuTelemetry.phase==Phase::Held&&"successful character swipe must resume Held without 1500ms recalibration");
    assert(robotImuPose.angle>0&&robotImuPose.x>0);
    assert(robotImu.result().event==robot_home::imu::Event::None&&robotImu.result().since==0);
    // Freshness is judged at touch BEGIN, ahead of its 65ms press frame.
    reset();calibrate();now+=80;selectedPause();quietResume();assert(robotImuTelemetry.phase==Phase::Held);
    // An unrelated stale interval BEFORE touch cannot acquire a resume grant.
    reset();calibrate();now+=121;selectedPause();quietResume();expectCalibration();
    // Precisely the existing 250ms quiet boundary, with zero suspended samples.
    reset();calibrate();selectedPause();release();const auto quietSamples=robotImuTelemetry.samples;
    feed(positive,240);sample(positive,9);assert(robotImuTelemetry.samples==quietSamples);
    sample(positive,1);assert(robotImuTelemetry.samples==quietSamples+1&&robotImuTelemetry.phase==Phase::Held);

    // All three local directions work from portrait and every full-body role.
    for(auto direction:{Direction::Up,Direction::Down,Direction::Right}){
      for(unsigned role=0;role<9;++role){
        reset();calibrate();
        if(role){entropy=role-1;selectedPause(direction);quietResume();assert(static_cast<unsigned>(robotCharacters.character())==role);}
        const auto pickups=robotImuTelemetry.pickups,samples=robotImuTelemetry.samples;
        selectedPause(direction);assert(robotImuTelemetry.samples==samples);quietResume();
        assert(robotImuTelemetry.phase==Phase::Held&&robotImuTelemetry.pickups==pickups);
        assert(robotImuPose.angle>0&&robotImuPose.x>0);
        feed(negative,180);assert(robotImuPose.angle<0&&robotImuPose.x<0);
      }
    }
    // Immediate second touch arrives before the first quiet window finishes.
    reset();calibrate();selectedPause();release();sample(positive,40);
    begin();feed(moving,60);swipe(Direction::Right);feed(moving,100);quietResume();
    assert(robotImuTelemetry.phase==Phase::Held&&robotImuTelemetry.pickups==1);
    // A second ordinary touch/left swipe must revoke the first grant.
    for(bool left:{false,true}){
      reset();calibrate();selectedPause();release();sample(positive,40);
      begin();sample(moving);if(left)swipe(Direction::Left);quietResume();expectCalibration();
    }
    // Finger and separately extended haptic both hold the quiet deadline open.
    reset();calibrate();selectedPause();const auto paused=robotImuTelemetry.samples;
    feed(moving,1200);assert(robotImuTelemetry.samples==paused);
    release();startHaptic(77,700);feed(positive,680);assert(robotImuTelemetry.samples==paused);
    feed(positive,240);assert(robotImuTelemetry.samples==paused);feed(positive,40);
    assert(robotImuTelemetry.phase==Phase::Held&&robotImuTelemetry.pickups==1);
    // Resting resume stays still without a false Pickup and new motion needs 60ms.
    reset();calibrate(false);selectedPause();quietResume({});
    assert(robotImuTelemetry.phase==Phase::Resting&&robotImuTelemetry.pickups==0&&robotImuTelemetry.settles==0);
    assert(robotImuPose.scale==.95f&&robotImuPose.y==4);
    feed({},500);sample(moving);feed(moving,40);assert(robotImuTelemetry.phase==Phase::Resting);
    sample(moving);assert(robotImuTelemetry.phase==Phase::Held&&robotImuTelemetry.pickups==1);
    // Even a pre-touch partial Pickup timer is discarded; the fresh first
    // motion sample starts a new 60ms qualification, with a new event timestamp.
    reset();calibrate(false);feed(moving,40);selectedPause();release();feed(moving,240);
    sample(moving,10);const auto newMotionAt=now;
    assert(robotImuTelemetry.phase==Phase::Resting&&robotImuTelemetry.pickups==0);
    sample(moving,20);sample(moving,20);assert(robotImuTelemetry.phase==Phase::Resting);
    sample(moving,20);assert(robotImuTelemetry.phase==Phase::Held&&robotImuTelemetry.pickups==1);
    assert(robotImu.result().event==robot_home::imu::Event::Pickup&&robotImu.result().since==newMotionAt);
    // Neutral orientation is retained across a resume from a tilted baseline.
    reset();const Sample neutral{0,.342020f,.939693f,0,0,0};feed(neutral,1600);feed(moving,80);
    selectedPause();quietResume({0,.5f,.866025f,25,0,0});
    assert(robotImuTelemetry.phase==Phase::Held&&robotImuPose.angle>0&&robotImuPose.angle<3);
    // Old 400ms stillness cannot contribute to the new 600ms settle interval.
    reset();calibrate();feed({},420);selectedPause();quietResume({});
    assert(robotImuTelemetry.phase==Phase::Held&&robotImuTelemetry.settles==0);
    feed({},560);assert(robotImuTelemetry.phase==Phase::Held);sample();
    assert(robotImuTelemetry.phase==Phase::Resting&&robotImuTelemetry.settles==1);
    // No calibrated state means no bypass of startup's 1500ms stillness.
    reset();feed({},200);selectedPause();quietResume();expectCalibration();
    sample();sample();feed({},1480);expectCalibration();sample();assert(robotImuTelemetry.phase==Phase::Resting);
    // Ordinary tap, below-threshold drag and left keep full recalibration.
    for(int gesture=0;gesture<3;++gesture){
      reset();calibrate();begin();feed(moving,40);
      if(gesture==1)updateTouchGesture(220,200);if(gesture==2)swipe(Direction::Left);
      quietResume();expectCalibration();assert(robotImuTelemetry.pickups==1);
    }
    // Actual workspace transitions away and back revoke even with NO IMU tick
    // between them; a state-only fixture would miss this lifecycle boundary.
    for(bool afterSelection:{false,true}){
      reset();calibrate();begin();sample(moving);if(afterSelection)swipe();
      handleWorkspaceModeTransition(workspace_mode::Mode::Home,workspace_mode::Mode::Codex);
      state.workspaceMode=workspace_mode::Mode::Codex;
      handleWorkspaceModeTransition(workspace_mode::Mode::Codex,workspace_mode::Mode::Home);
      state.workspaceMode=workspace_mode::Mode::Home;
      swipe();quietResume();expectCalibration();
    }
    // Physical buttons and pending power invalidate before and after selection.
    for(int boundary=0;boundary<7;++boundary){
      for(bool afterSelection:{false,true}){
        reset();calibrate();begin();sample(moving);if(afterSelection)swipe();
        switch(boundary){
          case 0:M5.BtnA.pressed=true;break;
          case 1:M5.BtnB.pressed=true;break;
          case 2:beginPowerButtonPress();finishPowerButtonPress();break;
          case 3:powerOverlay=dashboard::PowerOverlay::Hold;break;
          case 4:robotImuEnabled=false;break;
          case 5:M5.Imu.available=false;break;
          case 6:deskSleeping=true;robotImuWakeAllowed=false;break;
        }
        sample(moving);
        M5.BtnA.pressed=M5.BtnB.pressed=false;powerButtonGesture.cancel();
        powerOverlay=dashboard::PowerOverlay::None;robotImuEnabled=true;M5.Imu.available=true;deskSleeping=false;
        if(!afterSelection)swipe();quietResume();expectCalibration();
      }
    }
    // A real power-hold overlay is revoked even if finish clears the overlay
    // before any IMU tick can observe it.
    reset();calibrate();selectedPause();release();sample(positive,40);begin();
    beginTouchPowerHoldCandidate();now+=2000;updateTouchPowerHold();
    assert(powerOverlay==dashboard::PowerOverlay::HoldToPowerOff);
    release();feed(positive,400);expectCalibration();
    // Exercise actual manual sleep/reset and wake before the next sample.
    reset();calibrate();selectedPause();enterDeskSleep();assert(deskSleeping);
    wakeDeskSleep();quietResume();expectCalibration();
    // The existing actual two-key chord disables and re-enables the pilot;
    // neither toggle may resurrect a paused character-swipe snapshot.
    reset();calibrate();selectedPause();M5.BtnA.pressed=M5.BtnB.pressed=true;
    feed(moving,2100);assert(!robotImuEnabled);
    M5.BtnA.pressed=M5.BtnB.pressed=false;feed(moving,300);
    M5.BtnA.pressed=M5.BtnB.pressed=true;feed(moving,2100);assert(robotImuEnabled);
    M5.BtnA.pressed=M5.BtnB.pressed=false;quietResume();expectCalibration();
    // Power press/release can be canceled by gesture noteActivity before the
    // next IMU tick, so revoke on the actual power edge as well.
    reset();calibrate();begin();sample(moving);beginPowerButtonPress();finishPowerButtonPress();
    swipe();quietResume();expectCalibration();
    // A malformed first resumed sample consumes the grant and recalibrates.
    for(int bad=0;bad<4;++bad){
      reset();calibrate();selectedPause();release();feed(positive,240);
      if(bad==0)M5.Imu.mask=1;
      sample(bad==1?Sample{NAN,0,1,0,0,0}:bad==2?Sample{0,0,.1f,0,0,0}:bad==3?Sample{0,0,1,1001,0,0}:positive,20);
      M5.Imu.mask=3;feed(positive,100);expectCalibration();
    }
    // A successful grant is single-use; unrelated >120ms gaps still reset.
    reset();calibrate();selectedPause();quietResume();assert(robotImuTelemetry.phase==Phase::Held);
    sample(positive,121);expectCalibration();
    reset();calibrate();sample(positive,121);expectCalibration();
    // Existing 65ms presentation bookkeeping consumes the resumed dirty pose;
    // the outer loop presents once and the next 73ms sample stays Held.
    reset();calibrate();selectedPause();quietResume();
    const auto frames=presentedFrames;assert(frameDue());drawScreen();assert(!frameDue());
    sample(positive,8);assert(robotImuTelemetry.phase==Phase::Held);
    assert(presentedFrames==frames+1&&!frameDue()&&robotImuTelemetry.gapMaxMs<=120);
  }
CPP
Dir.mktmpdir('home-imu-swipe-','/private/tmp') do |dir|
  file=File.join(dir,'test.cpp');binary=File.join(dir,'test')
  File.write(file,fixture)
  system('clang++','-std=c++17','-fsanitize=address,undefined','-I'+File.join(repo,'include'),'-I'+File.join(repo,'usb-mic/.pio/libdeps/m5stack-stopwatch-usb-mic/ArduinoJson/src'),file,'-o',binary) or abort 'compile failed'
  system(binary) or abort 'actual touch/IMU swipe resume regression failed'
end
puts 'PASS actual touch/IMU swipe resume: U/D/R, all 9 roles, repeated/chained swipes, physical touch/haptic quiet, Held +/- tilt, Resting motion qualification, neutral/timer reset, startup/tap/left, actual workspace/power edges, button/overlay/disable/unavailable/sleep, bad samples, single-use/long gaps, 65ms render bookkeeping'
