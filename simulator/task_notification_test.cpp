#include <cassert>
#include <cstring>
#include <cstdio>
#include <ArduinoJson.h>
#include "TaskNotification.h"

using namespace task_notification;
Card approval() {
  Card c; c.g=12;c.id=7;c.r=3;c.count=2;c.ttl=15000;c.alert=2;c.decide=true;
  std::strcpy(c.src,"deepseek");std::strcpy(c.kind,"approval");
  std::strcpy(c.title,"Synthetic task");std::strcpy(c.model,"Model");
  std::strcpy(c.detail,"Run: echo test. Scope: once in synthetic workspace.");
  std::strcpy(c.state,"pending");return c;
}
void ack(Controller& ui,Card& c,uint32_t now) {
  Action a;assert(ui.takeAction(a));c.ack=a.seq;c.alert=0;
  assert(ui.receive(c,now));
}
int main() {
  Card c=approval();
  StaticJsonDocument<1536> d;
  auto e=deserializeJson(d,R"({"v":1,"g":12,"id":7,"r":3,"src":"deepseek","kind":"approval","title":"Synthetic task","model":"Model","detail":"Scope: once","state":"pending","count":2,"ttl":15000,"alert":2,"decide":true})");
  assert(!e);Card parsed;assert(parse(d.as<JsonObjectConst>(),parsed));
  assert(parsed.g==12&&parsed.id==7&&parsed.decide);
  assert(!parsed.muteLegacyCodex);
  d["muteLegacyCodex"]=true;assert(parse(d.as<JsonObjectConst>(),parsed)&&parsed.muteLegacyCodex);
  d["muteLegacyCodex"]="true";assert(!parse(d.as<JsonObjectConst>(),parsed));d.remove("muteLegacyCodex");
  Snapshot ownership;ownership.card=parsed;ownership.card.muteLegacyCodex=true;ownership.ready=true;ownership.receivedAt=0xfffffff0u;
  assert(ownsLegacyCodexCompletion(ownership,0xfffffff0u+14999u));
  assert(!ownsLegacyCodexCompletion(ownership,0xfffffff0u+15000u));
  ownership.ready=false;assert(!ownsLegacyCodexCompletion(ownership,0));
  ownership.ready=true;ownership.card.muteLegacyCodex=false;assert(!ownsLegacyCodexCompletion(ownership,0));
  d["g"]=-1;assert(!parse(d.as<JsonObjectConst>(),parsed));d["g"]=12;
  d["ttl"]=15001;assert(!parse(d.as<JsonObjectConst>(),parsed));d["ttl"]=15000;
  d["title"]="\x01";assert(!parse(d.as<JsonObjectConst>(),parsed));d["title"]="Valid";
  d["decide"]="true";assert(!parse(d.as<JsonObjectConst>(),parsed));d["decide"]=true;
  d["src"]="other";assert(!parse(d.as<JsonObjectConst>(),parsed));d["src"]="codex";
  d["kind"]="done";assert(!parse(d.as<JsonObjectConst>(),parsed));
  d["kind"]="input";assert(!parse(d.as<JsonObjectConst>(),parsed));
  auto opts=d.createNestedArray("options");opts.add("A");opts.add("B");
  assert(parse(d.as<JsonObjectConst>(),parsed));
  Controller ui;assert(ui.receive(c,1000));
  assert(!ui.present(1000,false));assert(!ui.visible());
  assert(ui.present(1050,true));assert(ui.view()==View::Toast);
  Controller epoch;Card oldEpoch=approval();
  assert(epoch.receive(oldEpoch,100));assert(!epoch.present(100,false));
  Card newEpoch=oldEpoch;newEpoch.g++;newEpoch.alert=0;
  assert(epoch.receive(newEpoch,110));
  assert(!epoch.present(120,true));assert(epoch.takeAlert()==0); // no queued toast/pulse crosses an epoch
  newEpoch.id++;newEpoch.alert=1;assert(epoch.receive(newEpoch,130));
  assert(epoch.present(130,true)&&epoch.takeAlert()==1); // a new native alert still presents
  ui.press(233,233,1060,false);ui.release(233,233,1070);
  assert(ui.view()==View::Toast); // first wake touch cannot open or decide
  ui.press(233,233,1080,true);ui.release(233,233,1090);
  assert(ui.view()==View::Detail);ack(ui,c,1100);
  ui.press(140,305,1110,true);ui.release(140,305,1120);
  assert(ui.view()==View::Confirm);Action a;assert(!ui.takeAction(a));
  ui.tick(3000);assert(!ui.takeAction(a)); // choosing never starts the hold
  ui.press(233,320,3100,true);ui.move(255,320,3200);ui.tick(4000);
  assert(!ui.takeAction(a));ui.release(255,320,4010);
  ui.press(233,320,4100,true);ui.tick(4899);assert(!ui.takeAction(a));
  // A same-revision heartbeat does not cancel or restart a valid fresh hold.
  assert(ui.receive(c,4850));ui.tick(4900);
  assert(ui.takeAction(a));assert(a.action==ActionKind::AllowOnce&&a.g==12&&a.id==7&&a.r==3);
  assert(ui.view()==View::Submitting);ui.tick(6000);assert(!ui.takeAction(a));
  Card other=c;other.id=8;std::strcpy(other.title,"Other");
  assert(ui.receive(other,6100));assert(ui.card().id==7); // detail pinned
  std::strcpy(c.state,"resolved");c.ack=a.seq;
  assert(ui.receive(c,6200));assert(ui.view()==View::Detail&&!ui.canDecide(6200));
  Controller expiry;assert(expiry.receive(approval(),0xfffffff0u));
  assert(expiry.present(0xfffffff0u,true));
  assert(expiry.canDecide(0xfffffff0u+14999u));assert(!expiry.canDecide(0xfffffff0u+15000u));
  expiry.disconnect();assert(!expiry.canDecide(1));
  Controller stale;assert(stale.receive(approval(),10));stale.present(10,true);
  Card changed=approval();changed.r=2;assert(!stale.receive(changed,11));
  changed=approval();std::strcpy(changed.detail,"Different scope");
  assert(!stale.receive(changed,12));assert(!stale.canDecide(12));
  Controller browse;Card first=approval();first.alert=0;assert(browse.receive(first,100));
  browse.openInbox(110);ack(browse,first,120);browse.release(233,233,125);
  browse.press(233,300,130,true);browse.release(233,230,140);
  assert(browse.takeAction(a)&&a.action==ActionKind::Next);
  Card next=first;next.id=9;next.ack=a.seq;assert(browse.receive(next,150));
  assert(browse.card().id==9&&browse.view()==View::Inbox);
  Controller choices;Card input=approval();std::strcpy(input.kind,"input");input.optionCount=3;
  std::strcpy(input.options[0],"First");std::strcpy(input.options[1],"Second");std::strcpy(input.options[2],"Third");
  assert(choices.receive(input,100));choices.present(100,true);
  choices.press(233,233,110,true);choices.release(233,233,120);ack(choices,input,130);
  choices.press(233,350,140,true);choices.release(233,350,150);
  assert(choices.view()==View::Confirm&&!std::strcmp(choices.selection(),"choose2"));
  HapticSequence pulse;pulse.start(3,100);
  assert(pulse.tick(100)==Pulse::Start);assert(pulse.tick(129)==Pulse::None);
  assert(pulse.tick(130)==Pulse::Stop);assert(pulse.tick(249)==Pulse::None);
  assert(pulse.tick(250)==Pulse::Start);assert(pulse.tick(280)==Pulse::Stop);
  assert(pulse.tick(400)==Pulse::Start);assert(pulse.tick(430)==Pulse::Stop);
  assert(!pulse.active());
  std::puts("PASS notification parsing, pinned request, wake isolation, fresh 800ms hold, lease/wrap, disconnect, haptic schedule");
}
