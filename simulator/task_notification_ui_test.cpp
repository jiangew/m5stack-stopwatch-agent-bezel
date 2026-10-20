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
      if(text.value==std::string(c.detail,24))lowerBody=text.y>=195&&text.y+7*24+10<382&&text.size>=2.5f;
      if(text.value.find("UP/DOWN")!=std::string::npos||text.value.find("LEFT:")!=std::string::npos){
        assert(text.y>=375&&text.y<=410&&text.size<=1.5f);++compactHints;
      }
      if(text.value=="BACK")back=text.y==430;
    }
    assert(lowerTitle&&lowerBody&&back&&compactHints==2&&full.find(c.detail)!=std::string::npos);
  }
  Card readOnly=c;readOnly.decide=false;
  Controller detail;detail.receive(readOnly,100);detail.present(100,true);
  detail.press(233,233,110,true);detail.release(233,233,120);
  Canvas largeDetail;task_notification::render(largeDetail,detail,130);
  std::string readable;
  for(const auto& text:largeDetail.texts){
    readable+=text.value;
    if(text.y>=195&&text.y<=363)assert(text.datum==middle_center&&text.x==233&&text.size>=2.5f);
    if(text.value=="OPEN ON MAC")assert(text.y==392&&text.size>=2.5f);
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
  std::puts("PASS full decision scope rendered and offline decision controls removed");
}
