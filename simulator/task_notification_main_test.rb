# Test the actual main-loop notification input gate with real controller state.
require 'tmpdir'
root=File.expand_path('..',__dir__)
source=File.read(File.join(root,'src/main.cpp'))
signature='bool handleTaskNotifications() {'
first=source.index(signature) or abort 'RED: actual notification main-loop gate missing'
body=source.index('{',first);depth=1;last=body+1
while depth>0
 depth+=1 if source[last]=='{';depth-=1 if source[last]=='}';last+=1
end
gate=source[first...last]
button_first=source.index('  if (M5.BtnB.wasPressed()) {') or abort 'right button handlers missing'
button_last=source.index("#if !defined(CODEX_STOPWATCH_USB_MIC)\n  CodexMicroState latest",button_first) or abort 'right button boundary missing'
buttons=source[button_first...button_last]
fixture=<<~CPP
 #include <cassert>
 #include <cstring>
 #include <string>
 #include <vector>
 #include "TaskNotification.h"
 unsigned now=1000;unsigned millis(){return now;}
 struct Touch {bool down=false,held=false,up=false;int x=233,y=233;
 bool wasPressed()const{return down;}bool wasReleased()const{return up;}bool isPressed()const{return held;}} touch;
 struct Point{int x,y;};
 struct {struct {Touch getDetail(){return touch;}Point getTouchPointRaw(){return {touch.x,touch.y};}} Touch;
 struct {void convertRawXY(Point*,int){}} Display;
 struct Button{bool down=false,held=false,up=false;bool isPressed(){return held;}
 bool wasPressed(){return down;}bool wasReleased(){return up;}} BtnA,BtnB;} M5;
 namespace dashboard{enum class PowerOverlay{None,HoldToPowerOff};}
 dashboard::PowerOverlay powerOverlay=dashboard::PowerOverlay::None;
 bool leftPressed=false,rightPressed=false,touchTracking=false,voiceClickReleasePending=false,powerButtonPressed=false;
 bool deskSleeping=false,hapticActive=false,shouldRedraw=false;
 bool awake=true;unsigned wakes=0,draws=0,stops=0;
 bool noteActivity(){bool result=awake;awake=true;deskSleeping=false;++wakes;return result;}
 void drawScreen(){++draws;}void stopHaptic(){++stops;hapticActive=false;}
 task_notification::Controller taskNotificationUi;
 task_notification::HapticSequence taskNotificationPulses;
 uint32_t lastNotificationVersion=0,lastNotificationProgressDraw=0;
 bool taskBadgeTouch=false,taskBadgeCanOpen=false;int taskBadgeX=0,taskBadgeY=0;
 bool taskTouchOwned=false,taskLeftButtonOwned=false,taskRightButtonOwned=false;
 unsigned rightPressedAtMs=0,voiceTapBannerUntilMs=0,voiceClicks=0;
 bool voiceTapBannerVisible=false;
 constexpr unsigned kVoiceTapBannerMs=1000,kButtonHapticIntensity=176,kButtonHapticDurationMs=30,kVoiceClickPulseMs=20;
 const char* kVoiceChatCommandKey="synthetic-voice";
 struct {template<class... Args>void printf(const char*,Args...){}} Serial;
 void beginVoiceChatClick(){++voiceClicks;}void startHaptic(unsigned,unsigned){}void stopRobotReaction(){}
 namespace workspace_input {enum class Control{RightPhysicalButton};bool allowed(int,Control){return true;}}
 struct{int workspaceMode=0;} state;
 struct {task_notification::Snapshot value;std::vector<task_notification::Action> actions;
 auto notificationSnapshot(){return value;}
 bool sendNotificationAction(const task_notification::Action& action){actions.push_back(action);return true;}} codex;
 void updateTaskNotificationHaptics(uint32_t){}
 #{gate}
 void underlyingRightButton(){#{buttons}}
 int main(int argc,char** argv){
 auto& c=codex.value.card;c.g=1;c.id=1;c.r=1;c.count=1;c.ttl=15000;c.alert=2;c.decide=true;
 std::strcpy(c.src,"codex");std::strcpy(c.kind,"approval");std::strcpy(c.state,"pending");
 std::strcpy(c.title,"Synthetic task");std::strcpy(c.detail,"Synthetic once-only scope");
 codex.value.ready=true;codex.value.version=1;codex.value.receivedAt=now;
 if(argc>1){
   const std::string scenario=argv[1];
   assert(handleTaskNotifications()); // visible native notification
   if(scenario=="new-generation-touch"||scenario=="power-touch"){
     touch.down=true;touch.held=true;touch.y=320;
     if(scenario=="power-touch")powerButtonPressed=true;
     else {c.g=2;c.id=0;c.count=0;c.alert=0;++codex.value.version;}
     assert(handleTaskNotifications()); // the press belongs to the previous visible modal
     touch.down=false;++now;assert(handleTaskNotifications()); // held frame must not leak
     touch.held=false;touch.up=true;++now;assert(handleTaskNotifications()); // nor its release
     touch={};++now;assert(!handleTaskNotifications());
   }else{
     M5.BtnB.down=true;M5.BtnB.held=true;++now;
     assert(handleTaskNotifications());assert(!rightPressed);
     M5.BtnB.down=false;
     if(scenario=="right-timeout")now+=task_notification::kToastMs;
     else if(scenario=="right-back"){
       touch.down=true;touch.held=true;touch.y=430;++now;assert(handleTaskNotifications());
       touch.down=false;touch.held=false;touch.up=true;++now;assert(handleTaskNotifications());touch={};
     }else {c.g=2;c.id=0;c.count=0;c.alert=0;++codex.value.version;}
     ++now;handleTaskNotifications();assert(!taskNotificationUi.visible());
     M5.BtnB.held=false;M5.BtnB.up=true;++now;
     const bool swallowed=handleTaskNotifications();
     if(!swallowed)underlyingRightButton();
     assert(swallowed&&voiceClicks==0); // entire swallowed physical gesture remains owned until release
     M5.BtnB={};++now;assert(!handleTaskNotifications());
     M5.BtnB.down=true;M5.BtnB.held=true;underlyingRightButton();
     M5.BtnB.down=false;M5.BtnB.held=false;M5.BtnB.up=true;underlyingRightButton();
     assert(voiceClicks==1); // a fresh ordinary press/release still acts
   }
   std::puts("PASS notification-owned gesture survives timeout/back/generation/power exit");return 0;
 }
 touchTracking=true;touch.held=true;
 assert(!handleTaskNotifications());assert(!taskNotificationUi.visible()); // no stolen gesture
 touchTracking=false;touch={};++now;
 assert(handleTaskNotifications());assert(taskNotificationUi.view()==task_notification::View::Toast);
 // New gesture opens detail and emits READ, never native approval.
 touch.down=true;touch.held=true;++now;assert(handleTaskNotifications());
 touch.down=false;touch.held=false;touch.up=true;++now;assert(handleTaskNotifications());
 assert(codex.actions.size()==1&&codex.actions[0].action==task_notification::ActionKind::Read);
 c.alert=0;c.ack=codex.actions[0].seq;++codex.value.version;touch={};++now;handleTaskNotifications();
 assert(taskNotificationUi.view()==task_notification::View::Detail);
 // Native disconnect while viewing prevents all device decisions.
 codex.value.ready=false;++codex.value.version;++now;handleTaskNotifications();
 assert(!taskNotificationUi.canDecide(now));
 powerOverlay=dashboard::PowerOverlay::HoldToPowerOff;++now;
 assert(!handleTaskNotifications());assert(!taskNotificationUi.visible()); // physical power flow stays reachable
 std::puts("PASS actual notification main-loop gate: active gesture deferral, READ isolation, disconnect, physical power priority");
 }
CPP
Dir.mktmpdir('notification-main-','/private/tmp') do |dir|
 path=File.join(dir,'main.cpp');exe=File.join(dir,'test');File.write(path,fixture)
 abort 'compile failed' unless system('clang++','-std=c++17','-fsanitize=address,undefined',"-I#{root}/include",'-isystem',"#{root}/.pio/libdeps/m5stack-stopwatch/ArduinoJson/src",path,'-o',exe)
 abort 'notification main-loop regression failed' unless system(exe)
 passed=true
 %w[right-timeout right-back right-generation new-generation-touch power-touch].each do |scenario|
   passed=system(exe,scenario)&&passed
 end
 usb=File.join(dir,'usb-test')
 abort 'USB fixture compile failed' unless system('clang++','-std=c++17','-DCODEX_STOPWATCH_USB_MIC=1','-fsanitize=address,undefined',"-I#{root}/include",'-isystem',"#{root}/.pio/libdeps/m5stack-stopwatch/ArduinoJson/src",path,'-o',usb)
 %w[right-timeout right-back right-generation new-generation-touch power-touch].each do |scenario|
   passed=system(usb,scenario)&&passed
 end
 abort 'notification main-loop gesture regressions failed' unless passed
end
