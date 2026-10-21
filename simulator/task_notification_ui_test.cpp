#include <cassert>
#include <cstring>
#include <string>
#include <vector>
#include "TaskNotificationUi.h"
struct Canvas {
  struct Text {std::string value;int x,y;float size;textdatum_t datum;const std::uint8_t* font;};
  struct Rect {int x,y,w,h;};
  struct Circle {int x,y,r;};
  std::vector<Circle> circles;
  std::vector<std::string> strings;
  std::vector<Text> texts;
  std::vector<Rect> rectangles;
  const std::uint8_t* font=nullptr;
  void loadFont(const std::uint8_t* f){font=f;}
  void unloadFont(){font=nullptr;}
  float textSize=1;
  textdatum_t datum=middle_center;
  void fillScreen(unsigned){} void setTextFont(int){} void setTextSize(float size){textSize=size;}
  void setTextDatum(textdatum_t value){datum=value;} void setTextColor(unsigned){}
  void fillRoundRect(int x,int y,int w,int h,int,unsigned){rectangles.push_back({x,y,w,h});}
  void drawRoundRect(int,int,int,int,int,unsigned){}
  void fillRect(int,int,int,int,unsigned){}
  void fillSmoothCircle(int x,int y,int r,unsigned){circles.push_back({x,y,r});}
  void drawString(const char* s,int x,int y){strings.emplace_back(s);assert(font&&textSize==1);texts.push_back({s,x,y,textSize,datum,font});}
};
int main(){
  using namespace task_notification;
  Card c;c.g=1;c.id=1;c.r=1;c.count=2;c.ttl=15000;c.alert=2;c.decide=true;
  std::strcpy(c.src,"codex");std::strcpy(c.kind,"approval");std::strcpy(c.state,"pending");
  std::strcpy(c.title,"Synthetic task");
  for(int i=0;i<192;++i)c.detail[i]=char('a'+i%26);
  Controller inbox;inbox.receive(c,100);
  for(int count:{1,9,10,64}) {
    c.count=count;inbox.receive(c,100);
    Canvas badge;task_notification::badge(badge,inbox);
    assert(badge.texts.size()==1&&badge.texts[0].value==std::to_string(count));
    assert(badge.texts[0].x==378&&badge.texts[0].y==233&&badge.texts[0].datum==middle_center);
    assert(badge.circles.size()==2&&badge.circles[0].r==40&&badge.circles[1].r==39);
    for(auto circle:badge.circles)assert(circle.x==378&&circle.y==233);
  }
  for(int x:{330,378,426})for(int y:{185,233,281}) {
    assert(inbox.badge(x,y));
    assert((x-233)*(x-233)+(y-233)*(y-233)<233*233);
  }
  assert(!inbox.badge(329,233)&&!inbox.badge(427,233));
  assert(!inbox.badge(378,184)&&!inbox.badge(378,282));
  Controller empty;Canvas hidden;task_notification::badge(hidden,empty);
  assert(!empty.badge(378,233)&&hidden.texts.empty()&&hidden.circles.empty());
  for(bool toast:{false,true}){
    Controller layout;layout.receive(c,100);
    if(toast)layout.present(100,true);else layout.openInbox(100);
    Canvas frame;task_notification::render(frame,layout,110);
    bool lowerTitle=false,lowerBody=false,back=false;unsigned compactHints=0;std::string full;
    for(const auto& text:frame.texts){
      full+=text.value;
      if(text.value==c.title)lowerTitle=text.y>=120&&text.datum==middle_center;
      if(text.y>=195&&text.y<=363){assert(text.datum==middle_center&&text.x==233);}
      if(text.value==std::string(c.detail,24))lowerBody=text.y>=195&&text.y+7*24+10<382&&text.font==font_data::kSpaceMono24Vlw;
      if(text.value=="UP/DOWN: BROWSE"||text.value=="LEFT: DISMISS"||text.value=="TAP: DETAILS"||text.value=="RIGHT: BACK"){
        assert(text.y>=365&&text.y<=400&&text.font==font_data::kSpaceMono15Vlw);
        assert(text.datum==middle_left);++compactHints;
      }
      if(text.value=="BACK")back=text.y==430;
    }
    assert(lowerTitle&&lowerBody&&back&&compactHints==4&&full.find(c.detail)!=std::string::npos);
    auto hint=[&](const char* value)->const Canvas::Text&{
      for(const auto& text:frame.texts)if(text.value==value)return text;
      assert(false);return frame.texts.front();
    };
    assert(hint("UP/DOWN: BROWSE").x==hint("LEFT: DISMISS").x);
    assert(hint("TAP: DETAILS").x==hint("RIGHT: BACK").x);
    assert(hint("UP/DOWN: BROWSE").x<hint("TAP: DETAILS").x);
    assert(hint("UP/DOWN: BROWSE").y==hint("TAP: DETAILS").y);
    assert(hint("LEFT: DISMISS").y==hint("RIGHT: BACK").y);
  }
  Card readOnly=c;readOnly.decide=false;
  Controller detail;detail.receive(readOnly,100);detail.present(100,true);
  detail.press(233,233,110,true);detail.release(233,233,120);
  Canvas largeDetail;task_notification::render(largeDetail,detail,130);
  std::string readable;
  for(const auto& text:largeDetail.texts){
    readable+=text.value;
    if(text.y>=195&&text.y<=363)assert(text.datum==middle_center&&text.x==233&&text.font==font_data::kSpaceMono24Vlw);
    if(text.value=="OPEN ON MAC")assert(text.y==392&&text.font==font_data::kSpaceMono24Vlw);
  }
  assert(readable.find(c.detail)!=std::string::npos);
  Controller ui;ui.receive(c,100);ui.present(100,true);
  ui.press(233,233,110,true);ui.release(233,233,120);
  Action a;assert(ui.takeAction(a));c.ack=a.seq;c.alert=0;ui.receive(c,130);
  Canvas canvas;task_notification::render(canvas,ui,140);
  for(const auto& text:canvas.texts){
    if(text.y>=165&&text.y<=240)assert(text.datum==middle_center&&text.x==233);
    if(text.value==c.title)assert(text.datum==middle_center);
  }
  std::string joined;for(auto& s:canvas.strings)joined+=s;
  assert(joined.find(c.detail)!=std::string::npos);assert(joined.find("ALLOW ONCE")!=std::string::npos);
  canvas.strings.clear();ui.disconnect();task_notification::render(canvas,ui,150);
  joined.clear();for(auto& s:canvas.strings)joined+=s;
  assert(joined.find("ALLOW ONCE")==std::string::npos);assert(joined.find("OFFLINE")!=std::string::npos);
  for(const auto& item:std::vector<std::pair<const char*,const char*>>{{"codex","Codex"},{"deepseek","DSH"},{"super","Super"},{"hermes","Hermes"}}){
    Card named=c;std::strcpy(named.src,item.first);std::strcpy(named.title,"SUPER task");
    Controller names;names.receive(named,100);names.openInbox(110);
    Canvas frame;render(frame,names,120);
    assert(frame.texts[0].value.find(item.second)==0);
    for(const auto& text:frame.texts)assert(!text.value.empty()&&text.value!="Model A");
    assert(std::strcmp(names.card().title,"SUPER task")==0);
    if(!std::strcmp(item.first,"super"))assert(frame.strings[1]=="Super task");
  }
  Card modeled=c;std::strcpy(modeled.model,"actual-model-version");
  Controller modelRow;modelRow.receive(modeled,100);modelRow.openInbox(110);
  Canvas modeledFrame;render(modeledFrame,modelRow,120);
  assert(modeledFrame.texts[1].value==modeled.model);
  assert(modeledFrame.texts[1].font==dashboard::font_data::kSpaceMono18Vlw);
  std::puts("PASS full decision scope rendered and offline decision controls removed");
}
