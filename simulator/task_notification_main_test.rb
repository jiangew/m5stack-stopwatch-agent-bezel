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
fixture=<<~CPP
 #include <cassert>
 #include <cstring>
 #include <vector>
 #include "TaskNotification.h"
 unsigned now=1000;unsigned millis(){return now;}
 struct Touch {bool down=false,held=false,up=false;int x=233,y=233;
 bool wasPressed()const{return down;}bool wasReleased()const{return up;}bool isPressed()const{return held;}} touch;
 struct Point{int x,y;};
 struct {struct {Touch getDetail(){return touch;}Point getTouchPointRaw(){return {touch.x,touch.y};}} Touch;
 struct {void convertRawXY(Point*,int){}} Display;
 struct Button{bool isPressed(){return false;}} BtnA,BtnB;} M5;
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
 struct {task_notification::Snapshot value;std::vector<task_notification::Action> actions;
 auto notificationSnapshot(){return value;}
 bool sendNotificationAction(const task_notification::Action& action){actions.push_back(action);return true;}} codex;
 void updateTaskNotificationHaptics(uint32_t){}
 #{gate}
 int main(){
 auto& c=codex.value.card;c.g=1;c.id=1;c.r=1;c.count=1;c.ttl=15000;c.alert=2;c.decide=true;
 std::strcpy(c.src,"codex");std::strcpy(c.kind,"approval");std::strcpy(c.state,"pending");
 std::strcpy(c.title,"Synthetic task");std::strcpy(c.detail,"Synthetic once-only scope");
 codex.value.ready=true;codex.value.version=1;codex.value.receivedAt=now;
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
end
