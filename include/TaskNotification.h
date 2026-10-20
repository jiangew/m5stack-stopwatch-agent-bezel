// SPDX-License-Identifier: MIT
#pragma once

#include <ArduinoJson.h>
#include <algorithm>
#include <cstdint>
#include <cstdlib>
#include <cstring>

namespace task_notification {
constexpr uint32_t kLeaseMs=15000, kToastMs=5000, kConfirmMs=800;
constexpr std::size_t kMaximumBytes=512;
constexpr int kBadgeCenterX=398,kBadgeCenterY=233,kBadgeRadius=22,kBadgeHitRadius=32;

struct Card {
  uint32_t g=0,id=0,r=0,ttl=0,ack=0;
  uint8_t count=0,alert=0,optionCount=0;
  bool decide=false,muteLegacyCodex=false;
  char src[9]={},kind[9]={},title[49]={},model[33]={},detail[193]={},state[11]={};
  char outcome[10]={};
  char options[3][25]={};
};
struct Snapshot {Card card;uint32_t version=0,receivedAt=0;bool ready=false;};
inline bool ownsLegacyCodexCompletion(const Snapshot& snapshot,uint32_t now) {
  return snapshot.ready&&snapshot.card.muteLegacyCodex&&uint32_t(now-snapshot.receivedAt)<kLeaseMs;
}
inline bool oneOf(const char* s,const char* a,const char* b,const char* c,const char* d) {
  return !std::strcmp(s,a)||!std::strcmp(s,b)||!std::strcmp(s,c)||!std::strcmp(s,d);
}
template<std::size_t N> bool text(JsonVariantConst value,char (&out)[N]) {
  if(!value.is<const char*>())return false;
  const auto str=value.as<JsonString>();
  if(str.size()>=N)return false;
  for(std::size_t i=0;i<str.size();++i)
    if(static_cast<unsigned char>(str.c_str()[i])<32||static_cast<unsigned char>(str.c_str()[i])>126)return false;
  std::memcpy(out,str.c_str(),str.size());out[str.size()]=0;return true;
}
inline bool parse(JsonObjectConst value,Card& output) {
  Card c;
  if(!value["v"].is<unsigned>()||value["v"].as<unsigned>()!=1||
     !value["g"].is<uint32_t>()||!value["id"].is<uint32_t>()||!value["r"].is<uint32_t>()||
     !value["count"].is<unsigned>()||!value["ttl"].is<unsigned>()||
     !value["alert"].is<unsigned>()||!value["decide"].is<bool>())return false;
  c.g=value["g"];c.id=value["id"];c.r=value["r"];
  const unsigned count=value["count"],ttl=value["ttl"],alert=value["alert"];
  if(!c.g||count>64||ttl>kLeaseMs||alert>3||(c.id&&(!c.r||!count))||(!c.id&&count))return false;
  c.count=count;c.ttl=ttl;c.alert=alert;c.decide=value["decide"];
  if(value.containsKey("muteLegacyCodex")) {
    if(!value["muteLegacyCodex"].is<bool>())return false;c.muteLegacyCodex=value["muteLegacyCodex"];
  }
  if(value.containsKey("ack")) {if(!value["ack"].is<uint32_t>())return false;c.ack=value["ack"];}
  if(!text(value["src"],c.src)||!text(value["kind"],c.kind)||!text(value["title"],c.title)||
     !text(value["model"],c.model)||!text(value["detail"],c.detail)||!text(value["state"],c.state))return false;
  if(!oneOf(c.src,"codex","deepseek","super","hermes")||
     !oneOf(c.kind,"done","approval","input","failed")||
     !(oneOf(c.state,"pending","submitting","resolved","unknown")||!std::strcmp(c.state,"expired")))return false;
  if(!value["outcome"].isNull()&&(!text(value["outcome"],c.outcome)||
      !oneOf(c.outcome,"allowed","declined","answered","cancelled")||std::strcmp(c.state,"resolved")))return false;
  if(!value["options"].isNull()) {
    if(!value["options"].is<JsonArrayConst>())return false;
    const auto options=value["options"].as<JsonArrayConst>();
    if(options.size()<2||options.size()>3||std::strcmp(c.kind,"input"))return false;
    c.optionCount=options.size();
    for(unsigned i=0;i<c.optionCount;++i)if(!text(options[i],c.options[i])||!c.options[i][0])return false;
  }
  if(c.decide&&(!c.id||!c.ttl||!c.title[0]||!c.detail[0]||std::strcmp(c.state,"pending")||
      (std::strcmp(c.kind,"approval")&&(std::strcmp(c.kind,"input")||!c.optionCount))))return false;
  output=c;return true;
}
inline bool sameRequest(const Card& a,const Card& b){return a.g==b.g&&a.id==b.id&&a.r==b.r;}
inline bool sameContext(const Card& a,const Card& b){
  if(std::strcmp(a.src,b.src)||std::strcmp(a.kind,b.kind)||std::strcmp(a.title,b.title)||
     std::strcmp(a.model,b.model)||std::strcmp(a.detail,b.detail)||a.optionCount!=b.optionCount)return false;
  for(unsigned i=0;i<a.optionCount;++i)if(std::strcmp(a.options[i],b.options[i]))return false;
  return true;
}
enum class ActionKind:uint8_t {None,Next,Previous,Read,Dismiss,Open,AllowOnce,Decline,Choose0,Choose1,Choose2,Close};
inline const char* actionName(ActionKind a){
  const char* names[]={"","next","previous","read","dismiss","open","allow_once","decline","choose0","choose1","choose2","close"};
  return names[static_cast<unsigned>(a)];
}
struct Action {uint32_t g=0,id=0,r=0,seq=0;ActionKind action=ActionKind::None;};
inline void writeAction(JsonObject obj,const Action& a){
  obj["v"]=1;obj["g"]=a.g;obj["id"]=a.id;obj["r"]=a.r;obj["seq"]=a.seq;obj["action"]=actionName(a.action);
}
enum class View:uint8_t{Hidden,Toast,Inbox,Detail,Confirm,Submitting};
class Controller {
 public:
  const Card& card()const{return card_;}
  View view()const{return view_;}
  bool visible()const{return view_!=View::Hidden;}
  bool dirty(){const bool d=dirty_;dirty_=false;return d;}
  bool linked()const{return linked_;}
  bool canDecide(uint32_t now)const {
    return linked_&&currentContext()&&card_.decide&&card_.id&&!std::strcmp(card_.state,"pending")&&
        uint32_t(now-receivedAt_)<card_.ttl&&!busy_;
  }
  bool receive(const Card& c,uint32_t now){
    const bool same=sameRequest(card_,c);
    if(linked_&&latest_.g==c.g&&latest_.id==c.id&&c.r<latest_.r)return false;
    if(same&&!sameContext(card_,c)) {disconnect();return false;}
    const bool browsed=busy_&&c.ack==action_.seq&&(action_.action==ActionKind::Next||action_.action==ActionKind::Previous||action_.action==ActionKind::Dismiss);
    latest_.g=c.g;latest_.id=c.id;latest_.r=c.r;
    if(busy_&&c.ack==action_.seq){busy_=false;hasAction_=false;}
    if(visible()&&view_!=View::Toast&&!same&&card_.g==c.g&&!browsed) {
      card_.count=c.count;held_=false;pressed_=false;blocked_=true;dirty_=true;
      return true; // preserve displayed scope; only Close may use the latest wire identity
    }
    const bool generationChanged=card_.g&&card_.g!=c.g;
    if(generationChanged){view_=View::Hidden;held_=false;pressed_=false;busy_=false;hasAction_=false;
      pendingToast_=false;pendingAlert_=0;}
    if(!same){held_=false;pressed_=false;blocked_=true;}
    if(c.alert&&(!same||c.alert!=card_.alert)){pendingToast_=true;pendingAlert_=c.alert;}
    if(same&&view_==View::Submitting&&std::strcmp(c.state,"submitting"))view_=View::Detail;
    if(same&&view_==View::Confirm&&(!c.decide||std::strcmp(c.state,"pending"))){view_=View::Detail;held_=false;pressed_=false;blocked_=true;}
    card_=c;receivedAt_=now;linked_=true;dirty_=true;
    if(!c.id){view_=View::Hidden;pendingToast_=false;pendingAlert_=0;}
    return true;
  }
  void disconnect(){linked_=false;held_=false;pressed_=false;blocked_=true;card_.decide=false;pendingToast_=false;dirty_=true;}
  bool present(uint32_t now,bool idle){
    if(!pendingToast_||!idle||view_==View::Detail||view_==View::Confirm||view_==View::Submitting||view_==View::Inbox)return false;
    pendingToast_=false;view_=View::Toast;toastAt_=now;blocked_=false;dirty_=true;return true;
  }
  unsigned takeAlert(){const unsigned n=pendingAlert_;pendingAlert_=0;return n;}
  bool badge(int x,int y)const{return card_.count&&
      x>=kBadgeCenterX-kBadgeHitRadius&&x<=kBadgeCenterX+kBadgeHitRadius&&
      y>=kBadgeCenterY-kBadgeHitRadius&&y<=kBadgeCenterY+kBadgeHitRadius;}
  bool openInbox(uint32_t now){
    if(!card_.id)return false;view_=View::Inbox;pendingToast_=false;pressed_=false;held_=false;blocked_=true;dirty_=true;
    issue(ActionKind::Read,now);return true;
  }
  void press(int x,int y,uint32_t now,bool awake){
    if(!awake||blocked_||!visible()){pressed_=false;return;}
    pressed_=true;startX_=x;startY_=y;pressedAt_=now;
    held_=view_==View::Confirm&&x>=90&&x<=376&&y>=285&&y<=355&&canDecide(now);
  }
  void move(int x,int y,uint32_t){
    endX_=x;endY_=y;
    if(std::abs(x-startX_)>=20||std::abs(y-startY_)>=20)held_=false;
  }
  void release(int x,int y,uint32_t now){
    const bool accepted=pressed_&&!blocked_;
    pressed_=false;held_=false;blocked_=false;
    if(!accepted)return;
    const int dx=x-startX_,dy=y-startY_;
    if(view_==View::Toast||view_==View::Inbox){
      if(y>=412&&std::abs(dx)<20&&std::abs(dy)<20){close(now);return;}
      if(std::abs(dy)>=52&&std::abs(dy)>std::abs(dx))issue(dy<0?ActionKind::Next:ActionKind::Previous,now);
      else if(dx>52){close(now);return;}
      else if(dx < -52)issue(ActionKind::Dismiss,now);
      else if(std::abs(dx)<20&&std::abs(dy)<20){view_=View::Detail;issue(ActionKind::Read,now);}
      dirty_=true;return;
    }
    if(std::abs(dx)>=20||std::abs(dy)>=20)return;
    if(y>=412){if(view_==View::Confirm)view_=View::Detail;else close(now);dirty_=true;return;}
    if(view_==View::Confirm||view_==View::Submitting)return;
    if(y>=376&&y<409){issue(ActionKind::Open,now);return;}
    if(!canDecide(now))return;
    if(card_.optionCount){
      const int choice=(y-264)/36;
      if(y>=264&&choice<card_.optionCount&&y<264+36*card_.optionCount){
        selected_=static_cast<ActionKind>(static_cast<unsigned>(ActionKind::Choose0)+choice);view_=View::Confirm;dirty_=true;
      }
    }else if(y>=285&&y<=330&&x>=60&&x<=406){selected_=x<233?ActionKind::AllowOnce:ActionKind::Decline;view_=View::Confirm;dirty_=true;}
  }
  void tick(uint32_t now){
    if(view_==View::Toast&&uint32_t(now-toastAt_)>=kToastMs){view_=View::Hidden;dirty_=true;}
    if(view_==View::Confirm&&!canDecide(now)){view_=View::Detail;held_=false;dirty_=true;}
    if(held_&&uint32_t(now-pressedAt_)>=kConfirmMs){
      if(canDecide(now)&&issue(selected_,now)){view_=View::Submitting;held_=false;pressed_=false;dirty_=true;}
    }
    if(busy_&&uint32_t(now-actionAt_)>=kLeaseMs){busy_=false;hasAction_=false;dirty_=true;
      if(view_==View::Submitting){std::strcpy(card_.state,"unknown");view_=View::Detail;card_.decide=false;}}
  }
  uint32_t holdElapsed(uint32_t now)const{return held_?std::min(uint32_t(now-pressedAt_),kConfirmMs):0;}
  const char* selection()const{return actionName(selected_);}
  bool takeAction(Action& out){if(!hasAction_)return false;out=action_;hasAction_=false;return true;}
  void close(uint32_t now){if(busy_)return;if(card_.id)issue(ActionKind::Close,now);view_=View::Hidden;held_=false;pressed_=false;dirty_=true;}
  void suspend(){view_=View::Hidden;held_=false;pressed_=false;blocked_=true;dirty_=true;}
 private:
  bool currentContext()const{return card_.g==latest_.g&&card_.id==latest_.id&&card_.r==latest_.r;}
  bool issue(ActionKind kind,uint32_t now){
    if(busy_||!linked_||!card_.id||(!currentContext()&&kind!=ActionKind::Close))return false;
    if(kind==ActionKind::Close&&!latest_.id)return false;
    if(++seq_==0)++seq_;
    action_.g=kind==ActionKind::Close?latest_.g:card_.g;
    action_.id=kind==ActionKind::Close?latest_.id:card_.id;
    action_.r=kind==ActionKind::Close?latest_.r:card_.r;action_.seq=seq_;action_.action=kind;
    actionAt_=now;hasAction_=true;busy_=true;dirty_=true;return true;
  }
  Card card_;
  View view_=View::Hidden;
  bool linked_=false,dirty_=false,pendingToast_=false,pressed_=false,held_=false,blocked_=false,busy_=false,hasAction_=false;
  uint8_t pendingAlert_=0;
  uint32_t receivedAt_=0,toastAt_=0,pressedAt_=0,actionAt_=0,seq_=0;
  int startX_=0,startY_=0,endX_=0,endY_=0;
  ActionKind selected_=ActionKind::None;
  Action action_;
  Action latest_; // transport identity only; never replaces displayed/deciding context
};

enum class Pulse:uint8_t{None,Start,Stop};
class HapticSequence {
 public:
  void start(unsigned count,uint32_t now){remaining_=std::min(count,3u);on_=false;at_=now;}
  void cancel(){remaining_=0;on_=false;}
  bool active()const{return remaining_||on_;}
  Pulse tick(uint32_t now){
    if(!active()||int32_t(now-at_)<0)return Pulse::None;
    if(on_){on_=false;--remaining_;at_=now+120;return Pulse::Stop;}
    on_=true;at_=now+30;return Pulse::Start;
  }
 private:unsigned remaining_=0;bool on_=false;uint32_t at_=0;
};
} // namespace task_notification
