# Exercise the actual loop's cache-retention decision and the actual canvas.
require 'tmpdir'
repo=File.expand_path('..',__dir__)
source=File.read(File.join(repo,'src/main.cpp'))
first=source.index('  bool discardRobotPortraits=') or abort 'missing cache policy'
last=source.index('  if(state.workspaceMode==workspace_mode::Mode::Home &&',first) or abort 'missing policy end'
policy=source[first...last]
vstart=source.index('  const bool homeVisible=') or abort 'missing Home visibility'
visibility=source[vstart..source.index(';',vstart)]
fixture=<<~CPP
  #define main original_canvas_regression
  #include "#{repo}/simulator/robot_home_portrait_canvas_test.cpp"
  #undef main
  #include "WorkspaceMode.h"
  #include "RobotHomeFrame.h"
  namespace dashboard {enum class PowerOverlay {None,Hold};}
  auto powerOverlay=dashboard::PowerOverlay::None;
  auto activeSwipe=touch_gesture::Direction::None;
  bool deskSleeping=false,robotImuWakeAllowed=false;
  struct {workspace_mode::Mode workspaceMode=workspace_mode::Mode::Home;bool workspaceHostReady=true;} state;
  void cleanup(Canvas& canvas,bool homeVisible){#{policy}}
  bool visible(){#{visibility}return homeVisible;}
  int main(){
    reset();Canvas canvas;
    activeSwipe=touch_gesture::Direction::Left;
    state.workspaceHostReady=false;assert(visible()); // offline Connect feedback must paint
    state.workspaceHostReady=true;assert(!visible()); // sent Home-left skips old pixels
    activeSwipe=touch_gesture::Direction::None;assert(visible());
    canvas.preparePortraits(Character::BumblebeeFullbody);
    const auto decoded=Sprite::decodes;
    for(int cycle=0;cycle<20;++cycle){
      state.workspaceMode=workspace_mode::Mode::Super;cleanup(canvas,false);
      assert(Sprite::live==13); // optional action buffers are released
      state.workspaceMode=workspace_mode::Mode::Home;
      canvas.preparePortraits(Character::Bumblebee);
      assert(Sprite::decodes==decoded); // returning Home decodes zero JPEGs
      draw(canvas,character_art::assetFor(Character::Bumblebee));
      assert(Sprite::drawn==character_art::assetFor(Character::Bumblebee).bytes);
    }
    deskSleeping=true;state.workspaceMode=workspace_mode::Mode::Super;
    cleanup(canvas,false);assert(Sprite::live==0);
    deskSleeping=false;state.workspaceMode=workspace_mode::Mode::Home;
    canvas.preparePortraits();
    deskSleeping=true;robotImuWakeAllowed=true;
    cleanup(canvas,false);assert(Sprite::live==13); // existing IMU-wake retention
    canvas.clearPortraits();assert(Sprite::live==0);
    std::puts("PASS actual Home-return cache policy: 20 returns, zero JPEG decodes, actions freed, sleep/IMU retention preserved");
  }
CPP
Dir.mktmpdir('home-return-cache-','/private/tmp') do |dir|
  file=File.join(dir,'test.cpp');File.write(file,fixture)
  archive=Dir[File.join(repo,'.pio/build/native-preview/**/libM5GFX.a')].first or abort 'native-preview archive required'
  flags=['clang++','-std=c++17','-fsanitize=address,undefined','-DCODEX_STOPWATCH_HOME_IMU',
    '-I'+File.join(repo,'include'),'-isystem',File.join(repo,'.pio/libdeps/m5stack-stopwatch/M5GFX/src'),
    '-isystem',File.join(repo,'.pio/libdeps/m5stack-stopwatch/ArduinoJson/src'),'-isystem','/opt/homebrew/include/SDL2']
  abort 'compile failed' unless system(*flags,file,archive,'-L/opt/homebrew/lib','-lSDL2','-o',File.join(dir,'test'))
  abort 'Home-return cache regression failed' unless system(File.join(dir,'test'))
end
