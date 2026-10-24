# Exercise the actual firmware drawScreen body with real native UI renderers.
# Hardware/state acquisition is doubled; renderer, dispatch and pixels are not.
# Uses existing native-preview dependencies only; never invokes PlatformIO.
require 'tmpdir'
repo = File.expand_path('..', __dir__)
source = File.read(File.join(repo, 'src/main.cpp'))
constants = source.lines.grep(/^constexpr (?:uint8_t|uint32_t) k\w*Haptic\w* =/).join
def extract_draw_function(source, signature)
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
loop_function = extract_draw_function(source, 'void loop() {')
poll_first = loop_function.index('  codex.poll();') + '  codex.poll();'.length
poll_last = loop_function.index('  updatePowerButton();', poll_first)
default_first = loop_function.index('#if !defined(CODEX_STOPWATCH_USB_MIC)', poll_last)
default_last = loop_function.index('  updatePowerTelemetry();', default_first)
host_poll = loop_function[poll_first...poll_last] + loop_function[default_first...default_last]
archive = Dir[File.join(repo, '.pio/build/native-preview/**/libM5GFX.a')].first
abort 'Existing native-preview M5GFX archive required (no build/install attempted)' unless archive
prefix = ENV.fetch('HOMEBREW_PREFIX', '/opt/homebrew')
flags = ['clang++', '-std=c++17', '-fsanitize=address,undefined', "-I#{repo}/include",
  '-isystem', "#{repo}/usb-mic/.pio/libdeps/m5stack-stopwatch-usb-mic/ArduinoJson/src",
  '-isystem', "#{repo}/.pio/libdeps/m5stack-stopwatch/M5GFX/src", '-isystem', "#{prefix}/include/SDL2"]
link = [archive, "-L#{prefix}/lib", '-lSDL2']
fixture = <<~CPP
  #include <cassert>
  #include <cstring>
  #include <cstdio>
  #define main preview_main_entry
  #include "#{repo}/simulator/preview_main.cpp"
  #undef main
  #include "WorkspaceMode.h"
  #include "RobotHomeFrame.h"
  using workspace_mode::Mode;
  unsigned now=1000,advanceAfterPush=0;
  unsigned millis() { return now; }
  #{constants}
  bool hapticActive=false,shouldRedraw=false,touchTracking=false;
  uint32_t hapticUntilMs=0;
  unsigned pushes=0;
  struct Event {const char* kind;unsigned at;unsigned level;};
  std::vector<Event> events;
  unsigned motorLevel=0;
  struct {struct Power {void setVibration(uint8_t level){
    motorLevel=level;events.push_back({"motor",now,level});}} Power;} M5;
  #{extract_draw_function(source, 'void startHaptic(')}
  #{extract_draw_function(source, 'void stopHaptic() {')}
  #{extract_draw_function(source, 'void updateHaptic()')}
  bool deskSleeping=false, renderedWorkspaceModeValid=false, renderedHealthValid=false;
  bool charging=false, renderedCharging=false, renderedConnected=false;
  bool renderedQuotaStale=false, renderedDocked=false;
  int batteryPercent=82, renderedBatteryPercent=-1;
  unsigned lastDrawMs=0;
  robot_home::FrameClock robotFrames;
  bool robotInputDirty=false;int robotTouchX=233,robotTouchY=232;
  Mode renderedWorkspaceMode=Mode::Home;
  struct CodexMicroState { Mode workspaceMode=Mode::Codex; bool connected=true, workspaceHostReady=true;
    bool dirty=false;unsigned connectionEpoch=1; } state, nextState;
  struct {CodexMicroState snapshot(){return nextState;}} codex;
  struct {void reset(){}} navigationGesture;
  struct {void cancel(){}} workspaceCenterTap,robotTap;
  unsigned transitions=0,baselines=0;
  void handleWorkspaceModeTransition(Mode,Mode){}
  void detectAgentTransitions(const CodexMicroState&){++transitions;}
  void synchronizeAgentStatusBaseline(const CodexMicroState&){++baselines;}
  dashboard::LinkHealth renderedLinkHealth=dashboard::LinkHealth::Offline;
  dashboard::PowerOverlay powerOverlay=dashboard::PowerOverlay::None;
  touch_gesture::Direction activeSwipe=touch_gesture::Direction::None;
  void pollHost(){#{host_poll}}
  workspace_palette::Palette workspacePalette;
  robot_home::Animation robotAnimation;
  robot_home::CharacterSelector robotCharacters;
  float currentPowerHoldProgress() { return 0.56f; }
  #{extract_draw_function(source, 'super_workspace::PowerOverlay superPowerOverlay() {')}
  #{extract_draw_function(source, 'bool directionalWorkspaceActive() {')}
  #{extract_draw_function(source, 'super_workspace::State superWorkspaceState() {')}
  dashboard::State fixtureState;
  dashboard::State dashboardState() { return fixtureState; }
  // Only the physical panel transfer is a no-op; all rasterization is real.
  struct CountingPortrait : lgfx::LGFX_Sprite {
    inline static unsigned decodes=0;
    bool drawJpg(const std::uint8_t* bytes,std::uint32_t size,int x,int y) {
      ++decodes;return lgfx::LGFX_Sprite::drawJpg(bytes,size,x,y);
    }
  };
  struct Canvas : robot_home::PortraitCanvas<lgfx::LGFX_Sprite,CountingPortrait> { void pushSprite(int, int) {
    events.push_back({"push",now,motorLevel});++pushes;now+=advanceAfterPush;
  } } canvas;
  #{extract_draw_function(source, 'void drawScreen() {')}
  std::vector<unsigned char> pixels(lgfx::LGFX_Sprite& surface) {
    std::vector<unsigned char> bytes(466*466*3);
    surface.readRectRGB(0,0,466,466,bytes.data());
    return bytes;
  }
  int main() {
    #if defined(CODEX_STOPWATCH_USB_MIC)
    // Crossing expiry during physical transfer must still schedule resting pixels.
    canvas.setColorDepth(16);assert(canvas.createSprite(466,466));
    state.workspaceMode=Mode::Home;drawScreen();
    const unsigned warmDecodes=CountingPortrait::decodes;
    for(auto page:{Mode::CodexIdle,Mode::DeepseekIdle,Mode::SuperIdle}) {
      state.workspaceMode=page;drawScreen();
      state.workspaceMode=Mode::Home;drawScreen();
      assert(CountingPortrait::decodes==warmDecodes); // real drawScreen must retain idle pixels
    }

    state.workspaceMode=Mode::Home;now=100;robotAnimation.press(now);robotAnimation.release(now);
    advanceAfterPush=20;drawScreen();
    assert(!robotFrames.due(133,true,true,false));
    assert(robotFrames.due(134,true,true,false)); // include rendering time in 30fps cadence

    now=699;advanceAfterPush=2;drawScreen();
    assert(robotFrames.due(now,true,false,false));
    advanceAfterPush=0;drawScreen();assert(!robotFrames.due(now,true,false,false));
    robotAnimation.cancel();
    robotCharacters.select(touch_gesture::Direction::Up,100,[]{return 0u;});
    now=419;advanceAfterPush=2;drawScreen();
    assert(robotFrames.due(now,true,false,false));
    advanceAfterPush=0;drawScreen();assert(!robotFrames.due(now,true,false,false));
    state.workspaceMode=Mode::Codex;robotCharacters.reset();now=1000;
    #endif
    lgfx::LGFX_Sprite reference;
    for(auto* surface:{static_cast<lgfx::LGFX_Sprite*>(&canvas),&reference}) {
      surface->setColorDepth(16);
      assert(surface->createSprite(466,466));
      surface->setTextWrap(false);
    }
    // Real drawScreen must defer both rasterization and transfer until a short
    // pulse stops. A changed dashboard makes pixel retention/restoration visible.
    fixtureState=previewState("live");drawScreen();
    const auto beforePulse=pixels(canvas);const auto beforeDrawMs=lastDrawMs;
    fixtureState=previewState("offline");dashboard::render(reference,fixtureState);
    const auto afterPulse=pixels(reference);assert(beforePulse!=afterPulse);
    now=1000;events.clear();const auto beforePushes=pushes;
    startHaptic(kTouchHapticIntensity,kTouchHapticDurationMs);
    now=1001;advanceAfterPush=65;shouldRedraw=false;drawScreen();
    assert(shouldRedraw&&"deferred redraw request lost");
    nextState=state;nextState.dirty=true;pollHost();
    assert(shouldRedraw&&transitions==1&&baselines==0);
    nextState.dirty=false;
    for(int poll=0;poll<3;++poll){pollHost();assert(shouldRedraw&&transitions==1);}
    assert(pushes==beforePushes&&lastDrawMs==beforeDrawMs&&pixels(canvas)==beforePulse);
    now=hapticUntilMs-1;drawScreen();
    assert(shouldRedraw&&pushes==beforePushes&&pixels(canvas)==beforePulse);
    now=hapticUntilMs;const auto deadline=now;drawScreen();
    assert(!hapticActive&&motorLevel==0&&!shouldRedraw);
    assert(pushes==beforePushes+1&&lastDrawMs==deadline+65&&pixels(canvas)==afterPulse);
    assert(events.size()==3&&std::strcmp(events[1].kind,"motor")==0&&events[1].level==0);
    assert(events[1].at==deadline&&std::strcmp(events[2].kind,"push")==0&&events[2].level==0);
    std::printf("draw gate: motor %u..%ums; transfer %u..%ums; pending pixels restored\\n",
        events[0].at,events[1].at,events[2].at,lastDrawMs);
    // Sleeping display still takes the original early return, without raster.
    const auto beforeSleepPushes=pushes;deskSleeping=true;drawScreen();
    assert(pushes==beforeSleepPushes);deskSleeping=false;advanceAfterPush=0;
    for(const char* scene:{"live","ble","offline","live-stale","live-charging",
                          "live-unknown-battery","live-battery-0","live-battery-100",
                          "power-hold","power-off"}) {
      fixtureState=previewState(scene);
      for(bool pressed:{false,true}) {
        fixtureState.leftPressed=fixtureState.rightPressed=fixtureState.sendPressed=pressed;
        fixtureState.activeTouchAgent=pressed?2:-1;
        fixtureState.completedAgent=pressed?3:-1;
        dashboard::render(reference,fixtureState);
        const auto expected=pixels(reference);
        std::vector<unsigned char> active;
        for(auto mode:{Mode::Codex,Mode::CodexIdle,Mode::CodexOpening,Mode::CodexError}) {
          state.workspaceMode=mode;
          renderedHealthValid=false;renderedWorkspaceModeValid=false;
          drawScreen();
          assert(renderedHealthValid); // actual dashboard branch, not a fixture-only comparison
          assert(renderedLinkHealth==fixtureState.linkHealth);
          assert(renderedQuotaStale==fixtureState.quotaStale);
          assert(renderedDocked==fixtureState.docked);
          assert(pixels(canvas)==expected);
          if(mode==Mode::Codex) active=pixels(canvas);
          else assert(pixels(canvas)==active);
  #if defined(CODEX_STOPWATCH_USB_MIC)
          assert(renderedWorkspaceModeValid && renderedWorkspaceMode==mode);
          assert(directionalWorkspaceActive()==(mode!=Mode::Codex));
  #endif
        }
      }
    }
  #if defined(CODEX_STOPWATCH_USB_MIC)
    for(auto mode:{Mode::Super,Mode::SuperIdle,Mode::SuperOpening,Mode::SuperError,
                   Mode::Hermes,Mode::HermesIdle,Mode::HermesOpening,Mode::HermesError,
                   Mode::Deepseek,Mode::DeepseekIdle,Mode::DeepseekOpening,Mode::DeepseekError}) {
      state.workspaceMode=mode;
      drawScreen();
      assert(!renderedHealthValid && renderedWorkspaceMode==mode);
      super_workspace::render(reference,superWorkspaceState());
      assert(pixels(canvas)==pixels(reference));
    }
    state.workspaceMode=Mode::Home;
    drawScreen();
    assert(!renderedHealthValid && renderedWorkspaceMode==Mode::Home);
    // Every role reaches the actual drawScreen branch. A reference Canvas uses
    // the requested role explicitly, so a missing role argument in firmware
    // changes the action pixels and fails this comparison.
    robot_home::PortraitCanvas<lgfx::LGFX_Sprite> homeReference;
    homeReference.setColorDepth(16);assert(homeReference.createSprite(466,466));
    homeReference.setTextWrap(false);
    for(int role=0;role<13;++role) {
      robotCharacters.reset();now=2000;
      if(role>0)robotCharacters.select(role<7?touch_gesture::Direction::Up:touch_gesture::Direction::Down,
          now-320,[role]{return static_cast<unsigned>(role<7?role-1:role-7);});
      assert(static_cast<int>(robotCharacters.character())==role);
      for(bool skill:{false,true}) {
        robotAnimation.cancel();
        if(skill){robotAnimation.press(now-200);robotAnimation.release(now-200);}
        drawScreen();
        robot_home::State expected;
        expected.character=static_cast<robot_home::Character>(role);
        expected.connected=true;expected.batteryPercent=82;
        expected.nowMs=now;expected.mood=skill?robot_home::Mood::Skill:robot_home::Mood::Idle;
        expected.reactionElapsedMs=skill?200:0;
        homeReference.preparePortraits(expected.character);
        robot_home::render(homeReference,expected);
        assert(pixels(canvas)==pixels(homeReference));
        const auto beforeSleep=pixels(canvas);
        deskSleeping=true;now+=10;drawScreen();assert(pixels(canvas)==beforeSleep);
        deskSleeping=false;now-=10;drawScreen();assert(pixels(canvas)==beforeSleep);
        canvas.clearPortraits();drawScreen(); // same role must prepare again after explicit clear
        assert(pixels(canvas)==pixels(homeReference));
      }
    }
  #endif
  }
CPP
Dir.mktmpdir('codex-dashboard-', '/private/tmp') do |dir|
  file = File.join(dir, 'draw_test.cpp')
  File.write(file, fixture)
  failed = []
  [[], ['-DCODEX_STOPWATCH_USB_MIC']].each do |defines|
    binary = File.join(dir, defines.empty? ? 'default-test' : 'usb-mic-test')
    abort 'actual draw compile failed' unless system(*flags, *defines, file, *link, '-o', binary)
    failed << File.basename(binary) unless system(binary)
  end
  abort "actual draw pixel regression: #{failed.join(', ')}" unless failed.empty?
  preview = File.join(dir, 'preview')
  abort 'preview compile failed' unless system(*flags, File.join(repo, 'simulator/preview_main.cpp'), *link, '-o', preview)
  frames = %w[live codex-idle codex-opening codex-error].map do |scene|
    path = File.join(dir, scene + '.ppm')
    abort 'preview render failed' unless system(preview, path, scene, out: File::NULL)
    bytes = File.binread(path)
    header = "P6\n466 466\n255\n"
    abort 'unexpected preview format' unless bytes.start_with?(header) && bytes.bytesize == header.bytesize + 466*466*3
    bytes
  end
  abort 'Codex pending preview differs from installed dashboard fixture' unless frames.all? { |frame| frame == frames.first }
end
puts 'PASS actual drawScreen: default + USB-mic haptic gate/65ms transfer/pending pixel restore; Codex active/idle/opening/error equality; directional UIs; 13 Home roles/skills/sleep/clear; preview equality'
