# Actual firmware constants and functions; clock, motor/panel and host I/O are boundaries.
# Catches excessive drive, late stop, deadline restart/wrap, duplicate Home release,
# changed 55ms host-key pacing, and shutdown drawing with an old motor pulse active.
require 'tmpdir'
repo = File.expand_path('..', __dir__)
source = File.read(File.join(repo, 'src/main.cpp'))
def extract_haptic_function(source, signature)
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
constants = source.lines.grep(/^constexpr (?:uint8_t|uint32_t|int) k(?:\w*Haptic\w*|TouchKeyPulseMs|SwipeThresholdPx) =/).join
fixture = <<~CPP
  #include <cassert>
  #include <cstdint>
  #include <cstdio>
  #include <cstring>
  #include <vector>
  #include <stdexcept>
  #include "RobotHomeInteraction.h"
  #include "WorkspaceCenterTap.h"
  #include "WorkspaceMode.h"
  using touch_gesture::Direction;
  #{constants}
  constexpr const char* kAgentKeys[]={"AG00","AG01","AG02","AG03","AG04","AG05"};
  constexpr const char* kSendKey="ACT12";
  uint32_t now=1000;
  uint32_t millis(){return now;}
  struct Event {const char* kind;uint32_t at;int value;};
  std::vector<Event> events;
  uint8_t level=0;
  void record(const char* kind,int value=0){events.push_back({kind,now,value});}
  void delay(uint32_t duration){record("delay",duration);now+=duration;}
  bool hapticActive=false,touchTracking=false,touchPowerHoldConsumed=false;
  bool touchAgentPressed=false,touchSendPressed=false,touchPowerHoldCandidate=false,robotInputDirty=false;
  uint32_t hapticUntilMs=0;
  int8_t activeTouchAgent=-1;
  int robotTouchX=0,robotTouchY=0;
  Direction activeSwipe=Direction::None;
  robot_home::Tap robotTap;
  robot_home::Animation robotAnimation;
  workspace_input::CenterTap workspaceCenterTap;
  namespace dashboard {enum class PowerOverlay {None,PoweringOff};}
  dashboard::PowerOverlay powerOverlay=dashboard::PowerOverlay::None;
  struct PowerCut {};
  struct Power {void setVibration(uint8_t value){level=value;record("motor",value);}
    struct Pm {bool powerOff(){throw PowerCut{};}} M5pm1;} ;
  struct Display {void setBrightness(int value){record("brightness",value);}
    void sleep(){record("sleep");}void waitDisplay(){record("display-wait");}};
  struct Speaker {void stop(){record("speaker-stop");}void end(){record("speaker-end");}};
  struct {Power Power;Display Display;Speaker Speaker;} M5;
  struct {void println(const char*){}void flush(){}template<class... A>void printf(const char*,A...){}} Serial;
  using m5pm1_err_t=int;
  bool powerManagerReady=true;
  struct {m5pm1_err_t shutdown(){record("cut");throw PowerCut{};}} powerManager;
  void esp_restart(){assert(false);}
  void releaseControlsForPowerOff(){record("release");}
  // Panel rendering is timed here; the independent native test runs real drawScreen/pixels.
  void drawScreen(){record("draw",level);now+=65;record("present",level);}
  bool noteActivity(){return true;}
  void sendSwipeRelease(){record("swipe-release");}
  struct {workspace_mode::Mode workspaceMode=workspace_mode::Mode::Codex;bool workspaceHostReady=true;} state;
  bool directionalWorkspaceActive(){return state.workspaceMode!=workspace_mode::Mode::Codex;}
  struct Host {void sendKey(const char*,int value,int=-1){record("key",value);}
    void sendOpenWorkspace(){record("open");}} codex;
  #{extract_haptic_function(source, 'void startHaptic(')}
  #{extract_haptic_function(source, 'void stopHaptic() {')}
  #{extract_haptic_function(source, 'void updateHaptic()')}
  #{extract_haptic_function(source, 'void stopRobotReaction()')}
  #{extract_haptic_function(source, 'void requestRobotReaction()')}
  #{extract_haptic_function(source, 'void clearTouchCandidate() {')}
  #{extract_haptic_function(source, 'void commitTouchAgent()')}
  #{extract_haptic_function(source, 'void commitTouchSend()')}
  #{extract_haptic_function(source, 'void finishTouchGesture(int x, int y) {')}
  #{extract_haptic_function(source, '[[noreturn]] void enterTravelPowerOff() {')}
  void require(bool ok,const char* message){if(!ok)throw std::runtime_error(message);}
  void reset(){now=1000;events.clear();level=0;hapticActive=false;hapticUntilMs=0;}
  void profiles(){
    struct Profile {const char* name;uint8_t intensity;uint32_t duration;uint32_t wanted;};
    const Profile profiles[]{
      {"touch",kTouchHapticIntensity,kTouchHapticDurationMs,24},
      {"button",kButtonHapticIntensity,kButtonHapticDurationMs,24},
      {"swipe",kSwipeHapticIntensity,kSwipeHapticDurationMs,24},
      {"wake",kButtonHapticIntensity,kWakeHapticDurationMs,20}};
    bool ok=true;
    for(const auto& p:profiles){reset();startHaptic(p.intensity,p.duration);
      std::printf("%s: motor=%u requested=%ums expected=176/%ums\\n",p.name,level,hapticUntilMs-now,p.wanted);
      ok&=level==176&&hapticUntilMs-now==p.wanted;
      now+=p.wanted-1;updateHaptic();require(hapticActive,"stopped before deadline");
      ++now;updateHaptic();ok&=!hapticActive&&level==0;
    }
    require(ok,"actual haptic drive/deadline exceeds quiet profile");
  }
  void deadlines(){reset();startHaptic(kTouchHapticIntensity,kTouchHapticDurationMs);
    now=hapticUntilMs-1;updateHaptic();require(hapticActive,"early stop");
    now=hapticUntilMs;updateHaptic();require(!hapticActive&&level==0,"deadline missed");
    const auto count=events.size();updateHaptic();require(events.size()==count,"duplicate stop");
    reset();startHaptic(kSwipeHapticIntensity,kSwipeHapticDurationMs);const auto old=hapticUntilMs;
    now+=7;startHaptic(kSwipeHapticIntensity,kSwipeHapticDurationMs);
    now=old;updateHaptic();require(hapticActive,"restart retained stale deadline");
    now=hapticUntilMs;updateHaptic();require(!hapticActive,"restart missed deadline");
    for(uint32_t elapsed:{15u,16u}){reset();now=0xfffffff8u;startHaptic(kTouchHapticIntensity,16);
      now+=elapsed;updateHaptic();require(hapticActive==(elapsed<16),"wraparound deadline");}
  }
  void keys(){for(bool agent:{false,true}){reset();touchAgentPressed=agent;activeTouchAgent=agent?2:-1;touchSendPressed=!agent;
      if(agent)commitTouchAgent();else commitTouchSend();
      uint32_t on=0,off=0,down=0,up=0;unsigned drives=0;
      for(const auto& e:events){if(!std::strcmp(e.kind,"motor")){if(e.value){on=e.at;++drives;}else off=e.at;}
        if(!std::strcmp(e.kind,"key")){if(e.value)down=e.at;else up=e.at;}}
      std::printf("%s: motor window=%ums key window=%ums\\n",agent?"agent":"send",off-on,up-down);
      require(drives==1&&off-on==24,"touch key motor window isn't 24ms");
      require(up-down==55&&up==1000+55,"host key pacing changed");
      require(off<up&&!hapticActive&&!touchAgentPressed&&!touchSendPressed,"release order/state changed");
      const auto count=events.size();if(agent)commitTouchAgent();else commitTouchSend();
      require(events.size()==count,"duplicate touch commit");
    }}
  void home(){
  #if defined(CODEX_STOPWATCH_USB_MIC)
    reset();state.workspaceMode=workspace_mode::Mode::Home;
    touchTracking=true;robotTap.begin(200,200,now,true);robotAnimation.press(now);now+=40;
    finishTouchGesture(200,200);const auto count=events.size();finishTouchGesture(200,200);
    require(events.size()==count,"same release emits twice");
    require(events.size()==3&&!std::strcmp(events[0].kind,"draw")&&
        !std::strcmp(events[1].kind,"present")&&!std::strcmp(events[2].kind,"motor"),"Home haptic starts before first frame");
    require(events[0].value==0&&events[2].at==1105&&hapticUntilMs==1129,"Home pulse isn't 24ms after first frame");
    require(robotAnimation.mood(now)==robot_home::Mood::Skill,"Home response missing");
    std::printf("Home: present=%ums motor-on=%ums deadline=%ums; one accepted release\\n",events[1].at,events[2].at,hapticUntilMs);
    // A second accepted release can arrive before the old short pulse expires.
    now+=5;touchTracking=true;robotTap.begin(200,200,now,true);robotAnimation.press(now);
    events.clear();finishTouchGesture(200,200);
    require(events.size()==4&&!std::strcmp(events[0].kind,"motor")&&events[0].value==0&&
        !std::strcmp(events[1].kind,"draw")&&events[1].value==0&&
        !std::strcmp(events[2].kind,"present")&&!std::strcmp(events[3].kind,"motor")&&
        events[3].value==176,"overlapping Home release must stop old pulse before first frame");
    require(events[3].at==1175&&hapticUntilMs==1199,"new Home pulse starts before its own first frame");
    const auto repeatedCount=events.size();finishTouchGesture(200,200);
    require(events.size()==repeatedCount,"overlapping release repeats feedback");
    std::printf("Home overlap: old-stop=1110ms present=1175ms motor-on=1175ms deadline=1199ms\\n");
  #endif
  }
  void shutdown(){reset();startHaptic(kSwipeHapticIntensity,200);events.clear();
    try{enterTravelPowerOff();}catch(const PowerCut&){}
    uint32_t presented=0,on=0,off=0,released=0,cut=0;unsigned drives=0;
    for(const auto& e:events){if(!std::strcmp(e.kind,"motor")){if(e.value){on=e.at;++drives;}else off=e.at;}
      if(!std::strcmp(e.kind,"draw"))require(e.value==0,"shutdown draws with old pulse active");
      if(!std::strcmp(e.kind,"present"))presented=e.at;
      if(!std::strcmp(e.kind,"release"))released=e.at;
      if(!std::strcmp(e.kind,"cut"))cut=e.at;}
    std::printf("shutdown: confirmation=%ums prompt-wait=%ums cut=%ums\\n",off-on,released-presented,cut);
    require(drives==1&&off-on==24&&!hapticActive&&level==0,"shutdown confirmation isn't 24ms");
    require(released-presented==550&&cut==released,"shutdown wait/release order changed");
    require(touchPowerHoldConsumed&&powerOverlay==dashboard::PowerOverlay::PoweringOff,"shutdown state changed");
  }
  int main(int argc,char** argv){try{
    if(!std::strcmp(argv[1],"profiles"))profiles();
    if(!std::strcmp(argv[1],"deadlines"))deadlines();
    if(!std::strcmp(argv[1],"keys"))keys();
    if(!std::strcmp(argv[1],"home"))home();
    if(!std::strcmp(argv[1],"shutdown"))shutdown();
  }catch(const std::exception& e){std::fprintf(stderr,"FAIL %s: %s\\n",argv[1],e.what());return 1;}}
CPP
Dir.mktmpdir('haptic-main-', '/private/tmp') do |dir|
  file = File.join(dir, 'test.cpp')
  File.write(file, fixture)
  failed = []
  [[], ['-DCODEX_STOPWATCH_USB_MIC']].each do |defines|
    label = defines.empty? ? 'default' : 'usb-mic'
    binary = File.join(dir, label)
    abort 'actual haptic compile failed' unless system('clang++', '-std=c++17', '-fsanitize=address,undefined', "-I#{repo}/include",
      "-I#{repo}/usb-mic/.pio/libdeps/m5stack-stopwatch-usb-mic/ArduinoJson/src", *defines, file, '-o', binary)
    %w[profiles deadlines keys home shutdown].each do |scenario|
      failed << "#{label}/#{scenario}" unless system(binary, scenario)
    end
  end
  abort "haptic regressions: #{failed.join(', ')}" unless failed.empty?
end
puts 'PASS actual haptic boundaries: profiles, expiry/restart/wrap, 24ms motor + 55ms key, Home frame-before-single-pulse, shutdown 24ms/550ms'
