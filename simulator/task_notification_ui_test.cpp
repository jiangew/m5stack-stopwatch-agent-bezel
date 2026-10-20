#include <cassert>
#include <cstring>
#include <string>
#include <vector>
#include "TaskNotificationUi.h"
struct Canvas {
  struct Text {std::string value;int x,y;float size;textdatum_t datum;};
  struct Rect {int x,y,w,h;};
  struct Circle {int x,y,r;};
  std::vector<Circle> circles;
  std::vector<std::string> strings;
  std::vector<Text> texts;
  std::vector<Rect> rectangles;
  float textSize=1;
  textdatum_t datum=middle_center;
  void fillScreen(unsigned){} void setTextFont(int){} void setTextSize(float size){textSize=size;}
  void setTextDatum(textdatum_t value){datum=value;} void setTextColor(unsigned){}
  void fillRoundRect(int x,int y,int w,int h,int,unsigned){rectangles.push_back({x,y,w,h});}
  void drawRoundRect(int,int,int,int,int,unsigned){}
  void fillRect(int,int,int,int,unsigned){}
  void fillSmoothCircle(int x,int y,int r,unsigned){circles.push_back({x,y,r});}
  void drawString(const char* s,int x,int y){strings.emplace_back(s);texts.push_back({s,x,y,textSize,datum});}
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
    assert(badge.texts[0].x==402&&badge.texts[0].y==233&&badge.texts[0].datum==middle_center);
    assert(badge.circles.size()==2&&badge.circles[0].r==26&&badge.circles[1].r==25);
    for(auto circle:badge.circles)assert(circle.x==402&&circle.y==233);
  }
  for(int x:{368,402,436})for(int y:{199,233,267}) {
    assert(inbox.badge(x,y));
    assert((x-233)*(x-233)+(y-233)*(y-233)<233*233);
  }
  assert(!inbox.badge(367,233)&&!inbox.badge(437,233));
  assert(!inbox.badge(402,198)&&!inbox.badge(402,268));
  Controller empty;Canvas hidden;task_notification::badge(hidden,empty);
  assert(!empty.badge(402,233)&&hidden.texts.empty()&&hidden.circles.empty());
  for(bool toast:{false,true}){
    Controller layout;layout.receive(c,100);
    if(toast)layout.present(100,true);else layout.openInbox(100);
    Canvas frame;task_notification::render(frame,layout,110);
    bool lowerTitle=false,lowerBody=false,back=false;unsigned compactHints=0;std::string full;
    for(const auto& text:frame.texts){
      full+=text.value;
      if(text.value==c.title)lowerTitle=text.y>=120&&text.datum==middle_center;
      if(text.y>=195&&text.y<=323){assert(text.datum==middle_left&&text.x>=40&&text.x<=64);}
      if(text.value==std::string(c.detail,32))lowerBody=text.y>=195&&text.y+6*20+8<350&&text.size>=2;
      if(text.value.find("UP/DOWN")!=std::string::npos||text.value.find("LEFT:")!=std::string::npos){
        assert(text.y>=375&&text.y<=405&&text.size<=1.25f);++compactHints;
      }
      if(text.value=="BACK")back=text.y==430;
    }
    assert(lowerTitle&&lowerBody&&back&&compactHints==2&&full.find(c.detail)!=std::string::npos);
  }
  Controller ui;ui.receive(c,100);ui.present(100,true);
  ui.press(233,233,110,true);ui.release(233,233,120);
  Action a;assert(ui.takeAction(a));c.ack=a.seq;c.alert=0;ui.receive(c,130);
  Canvas canvas;task_notification::render(canvas,ui,140);
  for(const auto& text:canvas.texts){
    if(text.y>=165&&text.y<=240)assert(text.datum==middle_left&&text.x>=60&&text.x<=80);
    if(text.value==c.title)assert(text.datum==middle_center);
  }
  std::string joined;for(auto& s:canvas.strings)joined+=s;
  assert(joined.find(c.detail)!=std::string::npos);assert(joined.find("ALLOW ONCE")!=std::string::npos);
  canvas.strings.clear();ui.disconnect();task_notification::render(canvas,ui,150);
  joined.clear();for(auto& s:canvas.strings)joined+=s;
  assert(joined.find("ALLOW ONCE")==std::string::npos);assert(joined.find("OFFLINE")!=std::string::npos);
  std::puts("PASS full decision scope rendered and offline decision controls removed");
}
