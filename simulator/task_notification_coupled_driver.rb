# Build the real Controller and actual BLE send function for pipe-based host tests.
require 'tmpdir'
root=File.expand_path('..',__dir__)
source=File.read(File.join(root,'src/CodexMicroBle.cpp'))
first=source.index('bool CodexMicroBle::sendNotificationAction(') or abort 'production send missing'
body=source.index('{',first);depth=1;last=body+1
while depth>0
 depth+=1 if source[last]=='{';depth-=1 if source[last]=='}';last+=1
end
send_function=source[first...last]
fixture=<<~CPP
 #include <cassert>
 #include <iostream>
 #include <string>
 #include "TaskNotification.h"
 using String=std::string;
 uint32_t now=1000;uint32_t millis(){return now;}
 struct Characteristic{std::string value;
 void setValue(uint8_t* data,size_t count){value.assign(reinterpret_cast<char*>(data),count);}void notify(){}} characteristic;
 struct CodexMicroBle{bool notificationConnectionValid_=true;Characteristic* notificationActions_=&characteristic;
 task_notification::Snapshot latest;auto notificationSnapshot(){return latest;}
 bool sendNotificationAction(const task_notification::Action&);};
 #{send_function}
 int main(){
 task_notification::Controller ui;CodexMicroBle transport;std::string line;
 while(std::getline(std::cin,line)){
   StaticJsonDocument<2048> command;assert(!deserializeJson(command,line));
   now=command["now"]|1000u;const std::string op=command["op"].as<const char*>();
   if(op=="receive"){
     task_notification::Card card;assert(task_notification::parse(command["card"].as<JsonObjectConst>(),card));
     transport.latest.card=card;transport.latest.ready=true;transport.latest.receivedAt=now;
     ui.receive(card,now);
   }else if(op=="open"){assert(ui.openInbox(now));ui.release(233,233,now);}
   else if(op=="detail"){ui.press(233,233,now,true);ui.release(233,233,now+1);}
   else if(op=="confirm"){ui.press(140,305,now,true);ui.release(140,305,now+1);}
   else if(op=="hold"){ui.press(233,320,now,true);ui.tick(now+800);}
   else if(op=="open-on-mac"){
     ui.tick(now);ui.release(233,233,now);ui.press(233,390,now+1,true);ui.release(233,390,now+2);
   }else if(op=="next"||op=="previous"){
     const bool next=op=="next";
     ui.press(233,next?300:220,now+1,true);ui.release(233,next?220:300,now+2);
   }
   else if(op=="close")ui.close(now);
   else assert(false);
   task_notification::Action action;const bool issued=ui.takeAction(action);
   const bool accepted=issued&&transport.sendNotificationAction(action);
   if(issued&&!accepted)ui.disconnect(); // same failure path as the production main-loop gate
   StaticJsonDocument<1024> result;result["r"]=ui.card().r;result["detail"]=ui.card().detail;
   result["canDecide"]=ui.canDecide(now);result["view"]=static_cast<unsigned>(ui.view());
   result["linked"]=ui.linked();
   result["accepted"]=accepted;
   if(issued)task_notification::writeAction(result.createNestedObject("issued"),action);
   if(accepted){StaticJsonDocument<256> wire;assert(!deserializeJson(wire,characteristic.value));result["action"]=wire.as<JsonObjectConst>();}
   serializeJson(result,std::cout);std::cout<<std::endl;
 }
 }
CPP
Dir.mktmpdir('notification-coupled-','/private/tmp') do |dir|
 path=File.join(dir,'driver.cpp');File.write(path,fixture)
 abort 'coupled driver compile failed' unless system('clang++','-std=c++17','-fsanitize=address,undefined',"-I#{root}/include",'-isystem',"#{root}/.pio/libdeps/m5stack-stopwatch/ArduinoJson/src",path,'-o',ARGV.fetch(0))
end
