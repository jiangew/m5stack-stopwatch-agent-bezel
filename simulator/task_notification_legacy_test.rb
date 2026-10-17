# Compile the actual legacy transition detector with private-channel ownership.
require 'tmpdir'
root=File.expand_path('..',__dir__)
source=File.read(File.join(root,'src/main.cpp'))
first=source.index('void detectAgentTransitions(const CodexMicroState& latest) {') or abort 'transition detector missing'
body=source.index('{',first);depth=1;last=body+1
while depth>0
 depth+=1 if source[last]=='{';depth-=1 if source[last]=='}';last+=1
end
fixture=<<~CPP
 #include <cassert>
 #include <cstdio>
 #include "TaskNotification.h"
 #define CODEX_STOPWATCH_TASK_NOTIFICATIONS 1
 namespace dashboard {enum class AgentStatus {Idle,Working,Complete,RequiresInput};}
 struct CodexMicroState {dashboard::AgentStatus threads[6]={};};
 dashboard::AgentStatus classifyAgent(dashboard::AgentStatus state){return state;}
 dashboard::AgentStatus previousAgentStatuses[6]={};bool agentStatusObserved[6]={};
 unsigned now=1000,chimes=0,wakes=0;unsigned millis(){return now;}
 void startCompletionChime(int8_t){++chimes;}void noteActivity(){++wakes;}
 struct {task_notification::Snapshot value;auto notificationSnapshot(){return value;}} codex;
 #{source[first...last]}
 int main(){
 CodexMicroState state;detectAgentTransitions(state);
 auto finish=[&](){state.threads[0]=dashboard::AgentStatus::Working;detectAgentTransitions(state);
 state.threads[0]=dashboard::AgentStatus::Complete;detectAgentTransitions(state);
 assert(previousAgentStatuses[0]==dashboard::AgentStatus::Complete);};
 finish();assert(chimes==1); // default retains baseline
 codex.value.ready=true;codex.value.receivedAt=now;codex.value.card.muteLegacyCodex=true;
 finish();assert(chimes==1); // explicit and fresh owns presentation only
 state.threads[1]=dashboard::AgentStatus::RequiresInput;detectAgentTransitions(state);assert(wakes==1);
 now+=15000;finish();assert(chimes==2); // stale lease restores original path
 codex.value.receivedAt=now;codex.value.ready=false;finish();assert(chimes==3);
 codex.value.ready=true;codex.value.card.muteLegacyCodex=false;finish();assert(chimes==4);
 std::puts("PASS actual legacy detector: explicit fresh ownership, LEDs/baseline, input wake, stale/disconnect fallback");
 }
CPP
Dir.mktmpdir('notification-legacy-','/private/tmp') do |dir|
 path=File.join(dir,'main.cpp');exe=File.join(dir,'test');File.write(path,fixture)
 abort 'compile failed' unless system('clang++','-std=c++17','-fsanitize=address,undefined',"-I#{root}/include",'-isystem',"#{root}/.pio/libdeps/m5stack-stopwatch/ArduinoJson/src",path,'-o',exe)
 abort 'legacy transition regression failed' unless system(exe)
end
