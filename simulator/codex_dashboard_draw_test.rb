# Exercise the actual firmware drawScreen body with real native UI renderers.
# Hardware/state acquisition is doubled; renderer, dispatch and pixels are not.
# Uses existing native-preview dependencies only; never invokes PlatformIO.
require 'tmpdir'
repo = File.expand_path('..', __dir__)
source = File.read(File.join(repo, 'src/main.cpp'))
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
archive = Dir[File.join(repo, '.pio/build/native-preview/**/libM5GFX.a')].first
abort 'Existing native-preview M5GFX archive required (no build/install attempted)' unless archive
prefix = ENV.fetch('HOMEBREW_PREFIX', '/opt/homebrew')
flags = ['clang++', '-std=c++17', "-I#{repo}/include",
  "-I#{repo}/usb-mic/.pio/libdeps/m5stack-stopwatch-usb-mic/ArduinoJson/src",
  "-I#{repo}/.pio/libdeps/m5stack-stopwatch/M5GFX/src", "-I#{prefix}/include/SDL2"]
link = [archive, "-L#{prefix}/lib", '-lSDL2']
fixture = <<~CPP
  #include <cassert>
  #include <cstring>
  #define main preview_main_entry
  #include "#{repo}/simulator/preview_main.cpp"
  #undef main
  #include "WorkspaceMode.h"
  #include "RobotHomeFrame.h"
  using workspace_mode::Mode;
  unsigned now=1000,advanceAfterPush=0;
  unsigned millis() { return now; }
  void updateHaptic() {}
  bool deskSleeping=false, renderedWorkspaceModeValid=false, renderedHealthValid=false;
  bool charging=false, renderedCharging=false, renderedConnected=false;
  bool renderedQuotaStale=false, renderedDocked=false;
  int batteryPercent=82, renderedBatteryPercent=-1;
  unsigned lastDrawMs=0;
  robot_home::FrameClock robotFrames;
  bool robotInputDirty=false;int robotTouchX=233,robotTouchY=232;
  Mode renderedWorkspaceMode=Mode::Home;
  struct { Mode workspaceMode=Mode::Codex; bool connected=true, workspaceHostReady=true; } state;
  dashboard::LinkHealth renderedLinkHealth=dashboard::LinkHealth::Offline;
  dashboard::PowerOverlay powerOverlay=dashboard::PowerOverlay::None;
  touch_gesture::Direction activeSwipe=touch_gesture::Direction::None;
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
  struct Canvas : robot_home::PortraitCanvas<lgfx::LGFX_Sprite> { void pushSprite(int, int) {now+=advanceAfterPush;} } canvas;
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
  #endif
  }
CPP
Dir.mktmpdir('codex-dashboard-', '/private/tmp') do |dir|
  file = File.join(dir, 'draw_test.cpp')
  File.write(file, fixture)
  [[], ['-DCODEX_STOPWATCH_USB_MIC']].each do |defines|
    binary = File.join(dir, defines.empty? ? 'default-test' : 'usb-mic-test')
    abort 'actual draw compile failed' unless system(*flags, *defines, file, *link, '-o', binary)
    abort 'actual draw pixel regression' unless system(binary)
  end
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
puts 'PASS actual drawScreen: Codex active/idle/opening/error dashboard pixel equality; default + USB-mic; three directional UIs unchanged; preview equality'
