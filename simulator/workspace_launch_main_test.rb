# Compile actual firmware entry points with hardware-boundary doubles.
require 'tmpdir'
repo = File.expand_path('..', __dir__)
source = File.read(File.join(repo, 'src/main.cpp'))
ble = File.read(File.join(repo, 'src/CodexMicroBle.cpp'))
def extract(source, signature)
  first = source.index(signature) or abort "missing #{signature}"
  body = source.index('{', first)
  depth = 1
  last = body + 1
  while depth > 0
    depth += 1 if source[last] == '{'
    depth -= 1 if source[last] == '}'
    last += 1
  end
  source[first...last]
end
functions = ['void stopRobotReaction() {', 'void requestRobotReaction() {', 'bool directionalWorkspaceActive() {', 'void clearTouchCandidate() {',
  'void beginTouchGesture(int x, int y) {', 'void sendSwipePress(touch_gesture::Direction direction) {', 'void sendSwipeRelease() {',
  'void finishTouchGesture(int x, int y) {', 'super_workspace::State superWorkspaceState() {'].map { |s| extract(source, s) }.join("\n")
touch_start = source.index('  if (touch.wasPressed()) {') or abort 'missing touch loop'
touch_end = source.index('  if (touchTracking && touch.isPressed())', touch_start)
physical_start = source.index('  if (M5.BtnA.wasPressed()) {') or abort 'missing buttons'
physical_end = source.index('#if !defined(CODEX_STOPWATCH_USB_MIC)', physical_start)
fixture = <<~CPP
  #include <cassert>
  #include <string>
  #include <vector>
  #include "WorkspaceInputPolicy.h"
  #include "WorkspaceNavigation.h"
  #include "WorkspaceCenterTap.h"
  #include "RobotHomeInteraction.h"
  using workspace_mode::Mode;
  using touch_gesture::Direction;
  unsigned now=100; unsigned millis(){return now;}
  bool deskSleeping=false;
  struct { Mode workspaceMode=Mode::Home; bool workspaceHostReady=true,connected=true; } state;
  namespace dashboard {enum class PowerOverlay{None}; bool sendAtPoint(int x,int y){return workspace_input::inCenter(x,y);}}
  namespace super_workspace {
    enum class Profile{Super,Hermes,Deepseek};
    enum class HermesPresentation{Active,Idle,Opening,Error};
    struct State {Profile profile=Profile::Super;HermesPresentation hermesPresentation=HermesPresentation::Active;
      int borderColors=0,batteryPercent=0,powerOverlay=0;bool charging=false,connected=false;
      Direction swipeDirection=Direction::None;float powerHoldProgress=0;};
  }
  int superPowerOverlay(){return 0;} float currentPowerHoldProgress(){return 0;}
  struct {int colors(){return 0;}} workspacePalette;
  int batteryPercent=70;bool charging=false;
  dashboard::PowerOverlay powerOverlay=dashboard::PowerOverlay::None;
  workspace_input::CenterTap workspaceCenterTap;
  robot_home::Tap robotTap;
  robot_home::Animation robotAnimation;
  bool robotInputDirty=false;
  int robotTouchX=233,robotTouchY=232;
  workspace_navigation::Gesture navigationGesture;
  bool touchTracking=false,touchPowerHoldConsumed=false,touchPowerHoldCandidate=false;
  bool touchAgentPressed=false,touchSendPressed=false;
  int activeTouchAgent=-1, touchStartX=0,touchStartY=0,workspaceTouchEndX=0,workspaceTouchEndY=0;
  Direction activeSwipe=Direction::None;
  constexpr int kSwipeThresholdPx=52,kTouchHapticIntensity=1,kTouchHapticDurationMs=1;
  constexpr int kButtonHapticIntensity=2,kWakeHapticDurationMs=2,kButtonHapticDurationMs=2,kVoiceTapBannerMs=500,kVoiceClickPulseMs=30;
  int agentCommits=0,sendCommits=0,haptics=0,physicalEvents=0;
  std::vector<std::string> messages;
  class CodexMicroBle {public:
    void sendJson(const char* json){messages.push_back(json);}
    void sendOpenWorkspace();void sendOpenHermes();
    void sendNavigation(const workspace_navigation::Event& event){
      StaticJsonDocument<384> doc;workspace_navigation::write(doc.to<JsonObject>(),event);
      std::string json;serializeJson(doc,json);messages.push_back(json);
    }
  } codex;
  #{extract(ble, 'void CodexMicroBle::sendOpenWorkspace()')}
  #{extract(ble, 'void CodexMicroBle::sendOpenHermes()')}
  struct {template<class... A>void printf(const char*,A...){}} Serial;
  bool noteActivity(){bool awake=!deskSleeping;deskSleeping=false;return awake;}
  int draws=0,lastHapticMs=0;unsigned drawCost=0,hapticStartedAt=0;
  void drawScreen(){++draws;now+=drawCost;} void startHaptic(int,int duration){++haptics;lastHapticMs=duration;hapticStartedAt=now;}
  int8_t agentAtPoint(int x,int){return x<100?0:-1;}
  void beginTouchAgent(int8_t a){touchAgentPressed=true;activeTouchAgent=a;}
  void beginTouchSend(){touchSendPressed=true;}
  void beginTouchPowerHoldCandidate(){touchPowerHoldCandidate=true;}
  void commitTouchAgent(){++agentCommits;touchAgentPressed=false;}
  void commitTouchSend(){++sendCommits;touchSendPressed=false;}
  bool leftPressed=false,rightPressed=false,voiceTapBannerVisible=false;
  unsigned rightPressedAtMs=0,voiceTapBannerUntilMs=0;
  const char* kLeftMicSwitch="left";const char* kVoiceChatCommandKey="voice";
  void pressMicSwitch(const char*,bool& pressed){pressed=true;++physicalEvents;}
  void releaseMicSwitch(const char*,bool& pressed){pressed=false;++physicalEvents;}
  void beginVoiceChatClick(){++physicalEvents;}
  struct Button{bool pressed=false,released=false;bool wasPressed(){return pressed;}bool wasReleased(){return released;}};
  struct {Button BtnA,BtnB;} M5;
  #{functions}
  void touchDown(int touchX,int touchY){
    struct {bool wasPressed(){return true;}} touch;
    #{source[touch_start...touch_end]}
  }
  void buttons(){#{source[physical_start...physical_end]}}
  void reset(Mode mode){state.workspaceMode=mode;state.workspaceHostReady=true;deskSleeping=false;
    clearTouchCandidate();touchTracking=false;touchPowerHoldConsumed=false;activeSwipe=Direction::None;
    navigationGesture.reset();messages.clear();agentCommits=sendCommits=haptics=physicalEvents=0;
    leftPressed=rightPressed=false;M5.BtnA={};M5.BtnB={};now+=1000;robotAnimation.cancel();draws=0;}
  void tap(int x=233,int y=233){touchDown(x,y);now+=100;finishTouchGesture(x,y);}
  int main(){
    reset(Mode::Home);touchDown(233,233);
    assert(robotAnimation.mood(now)==robot_home::Mood::Press&&draws==1&&haptics==0);
    assert(messages.empty());now+=100;finishTouchGesture(233,233);
    assert(robotAnimation.mood(now)==robot_home::Mood::Skill&&draws==2);
    assert(haptics==1&&lastHapticMs==25&&messages.empty());
    now+=30;touchDown(233,233);assert(robotAnimation.mood(now)==robot_home::Mood::Press);
    now+=30;finishTouchGesture(233,233);assert(robotAnimation.elapsed(now)==0&&haptics==2);
    reset(Mode::Home);touchDown(233,233);now+=100;drawCost=60;finishTouchGesture(233,233);
    assert(hapticStartedAt==now); // render time must not lengthen motor pulse
    drawCost=0;
    reset(Mode::Home);deskSleeping=true;touchDown(233,233);
    assert(!touchTracking&&robotAnimation.mood(now)==robot_home::Mood::Idle&&draws==0);
    finishTouchGesture(233,233);assert(haptics==0&&messages.empty());
    reset(Mode::Home);touchDown(233,233);now+=500;finishTouchGesture(233,233);
    assert(robotAnimation.mood(now)==robot_home::Mood::Idle&&haptics==0&&messages.empty());
    reset(Mode::Home);touchDown(233,233);robotTap.move(20,233,52);now+=100;finishTouchGesture(233,233);
    assert(robotAnimation.mood(now)==robot_home::Mood::Idle&&haptics==0);
    reset(Mode::Home);tap(10,10);assert(draws==0&&haptics==0&&messages.empty());

    for(auto mode:{Mode::CodexIdle,Mode::CodexOpening,Mode::CodexError,
        Mode::DeepseekIdle,Mode::DeepseekOpening,Mode::DeepseekError,
        Mode::SuperIdle,Mode::SuperOpening,Mode::SuperError,
        Mode::HermesIdle,Mode::HermesOpening,Mode::HermesError}){
      reset(mode);assert(directionalWorkspaceActive());
      // Only the three directional UIs use this mapping; Codex pending keeps
      // dashboard drawing while retaining the isolated launch input route.
      if (!workspace_mode::isCodex(mode)) {
        const auto ui=superWorkspaceState();
        assert(ui.profile==(workspace_mode::isDeepseek(mode)?super_workspace::Profile::Deepseek:
            workspace_mode::isHermes(mode)?super_workspace::Profile::Hermes:super_workspace::Profile::Super));
        assert(ui.hermesPresentation==(workspace_mode::isIdle(mode)?super_workspace::HermesPresentation::Idle:
            workspace_mode::isOpening(mode)?super_workspace::HermesPresentation::Opening:super_workspace::HermesPresentation::Error));
      }
      tap();assert(messages.size()==(workspace_mode::canOpen(mode)?1u:0u));
      if(!messages.empty())assert(messages[0]==R"({"method":"host.open_workspace","params":{}})");
      assert(agentCommits==0&&sendCommits==0);
      reset(mode);tap(50,233);assert(messages.empty()&&agentCommits==0&&sendCommits==0);
      reset(mode);state.workspaceHostReady=false;tap();assert(messages.empty());
      reset(mode);deskSleeping=true;tap();assert(!deskSleeping&&messages.empty());
      reset(mode);touchDown(233,233);now+=500;finishTouchGesture(233,233);assert(messages.empty());
      reset(mode);touchDown(233,233);workspaceCenterTap.move(300,233,52);now+=100;finishTouchGesture(233,233);assert(messages.empty());
      reset(mode);touchDown(233,233);touchPowerHoldConsumed=true;now+=100;finishTouchGesture(233,233);assert(messages.empty());
      reset(mode);M5.BtnA.pressed=M5.BtnB.pressed=true;buttons();
      M5.BtnA.pressed=M5.BtnB.pressed=false;M5.BtnA.released=M5.BtnB.released=true;buttons();
      assert(physicalEvents==0&&!leftPressed&&!rightPressed);
      reset(mode);sendSwipePress(Direction::Up);sendSwipePress(Direction::Right);sendSwipePress(Direction::Down);assert(messages.empty());
      sendSwipePress(Direction::Left);assert(messages.size()==1);
      state.workspaceMode=Mode::Codex;sendSwipeRelease();assert(messages.size()==2);
      assert(messages[1].find("host.workspace_navigation")!=std::string::npos);
    }
    for(auto mode:{Mode::Deepseek,Mode::Super,Mode::Hermes}){reset(mode);tap();assert(messages.empty());}
    reset(Mode::Codex);assert(!directionalWorkspaceActive());tap();assert(sendCommits==1&&messages.empty());
    reset(Mode::Codex);tap(50,233);assert(agentCommits==1);
    reset(Mode::Codex);M5.BtnA.pressed=M5.BtnB.pressed=true;buttons();
    M5.BtnA.pressed=M5.BtnB.pressed=false;M5.BtnA.released=M5.BtnB.released=true;buttons();assert(physicalEvents==3);
    reset(Mode::HermesIdle);codex.sendOpenHermes();
    assert(messages[0]==R"({"method":"host.workspace_action","params":{"action":"open_hermes"}})");
  }
CPP
Dir.mktmpdir('workspace-launch-', '/private/tmp') do |dir|
  file = File.join(dir, 'test.cpp'); File.write(file, fixture)
  abort 'compile failed' unless system('clang++', '-std=c++17', '-DCODEX_STOPWATCH_USB_MIC',
    "-I#{repo}/include", "-I#{repo}/usb-mic/.pio/libdeps/m5stack-stopwatch-usb-mic/ArduinoJson/src",
    file, '-o', File.join(dir, 'test'))
  abort 'launch regression failed' unless system(File.join(dir, 'test'))
end
puts 'PASS actual main launch: four profiles, center/wake/hold, physical isolation, navigation, BLE compatibility'
