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
  // Footer targets must match the visible buttons, not a full-width bottom band.
  {
    struct Case {int x,y;ActionKind action;};
    for(const auto& check:{Case{148,368,ActionKind::Close},Case{318,368,ActionKind::Open},
        Case{70,336,ActionKind::Close},Case{240,336,ActionKind::Open},
        Case{70,316,ActionKind::Close},Case{395,316,ActionKind::Open},
        Case{148,315,ActionKind::None},Case{318,315,ActionKind::None},
        Case{233,316,ActionKind::None},Case{69,316,ActionKind::None},
        Case{225,370,ActionKind::Close},Case{226,370,ActionKind::None},
        Case{239,370,ActionKind::None},Case{396,370,ActionKind::None},
        Case{233,368,ActionKind::None},Case{326,414,ActionKind::None},
        Case{233,430,ActionKind::None},Case{125,426,ActionKind::None},Case{253,426,ActionKind::None}}){
      Card n=approval();n.decide=false;n.alert=0;Controller page;
      page.receive(n,100);page.openInbox(110);ack(page,n,120);page.release(233,233,125);
      page.press(check.x,check.y,130,true);page.release(check.x,check.y,140);
      Action a;const bool emitted=page.takeAction(a);
      if(check.action==ActionKind::None)assert(!emitted&&page.view()==View::Inbox);
      else {assert(emitted&&a.action==check.action);assert(page.visible()==(check.action!=ActionKind::Close));}
    }
    Card n=approval();n.decide=false;n.alert=0;Controller page;
    page.receive(n,100);page.openInbox(110);ack(page,n,120);page.release(233,233,125);
    page.press(318,395,130,true);page.release(318,412,140);
    Action a;assert(page.takeAction(a)&&a.action==ActionKind::Open&&page.view()==View::Inbox);
    n.ack=a.seq;page.receive(n,150);
    page.press(233,368,160,true);page.release(243,368,170);assert(!page.takeAction(a)); // gap cannot arm OPEN
    page.press(318,368,180,true);page.move(318,307,185);page.release(318,368,190);
    assert(!page.takeAction(a)); // returning after a drag cannot become a click
    page.press(318,368,200,true);page.release(318,290,210);
    assert(page.takeAction(a)&&a.action==ActionKind::Next);n.id++;n.ack=a.seq;page.receive(n,220);
    page.press(318,280,230,true);page.release(318,368,240);
    assert(page.takeAction(a)&&a.action==ActionKind::Previous);n.id--;n.ack=a.seq;page.receive(n,250);
    page.press(318,368,260,true);page.release(238,368,270);
    assert(page.takeAction(a)&&a.action==ActionKind::Dismiss);n.id++;n.ack=a.seq;page.receive(n,280);
    page.press(148,368,290,true);page.release(228,368,300);
    assert(page.takeAction(a)&&a.action==ActionKind::Close&&!page.visible());
    // The extra upper hit area locks its original button, but still yields to swipes.
    Controller upper;upper.receive(n,300);upper.openInbox(301);ack(upper,n,302);upper.release(233,233,303);
    upper.press(318,316,304,true);upper.release(318,330,305);
    assert(upper.takeAction(a)&&a.action==ActionKind::Open&&upper.view()==View::Inbox);
    n.ack=a.seq;upper.receive(n,306);
    upper.press(318,316,307,true);upper.move(318,296,308);upper.release(318,316,309);
    assert(!upper.takeAction(a));
    upper.press(318,316,310,true);upper.release(318,264,311);
    assert(upper.takeAction(a)&&a.action==ActionKind::Next);
    Controller toast;n.alert=1;n.ack=0;toast.receive(n,310);assert(toast.present(310,true));
    toast.press(233,233,320,true);toast.release(233,233,330);
    assert(toast.view()==View::Inbox&&toast.takeAction(a)&&a.action==ActionKind::Read);
    n.ack=a.seq;toast.receive(n,340);toast.press(233,233,350,true);toast.release(233,233,360);
    assert(!toast.takeAction(a));toast.tick(6000);assert(toast.view()==View::Inbox);
  }
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
  d["src"]="hermes";assert(!parse(d.as<JsonObjectConst>(),parsed));
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
  // An acknowledged browse must allow the very next physical swipe.
  browse.press(233,230,160,true);browse.release(233,300,170);
  assert(browse.takeAction(a)&&a.action==ActionKind::Previous);
  first.ack=a.seq;assert(browse.receive(first,180));
  browse.press(233,300,190,true);browse.release(233,230,200);
  assert(browse.takeAction(a)&&a.action==ActionKind::Next);

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
