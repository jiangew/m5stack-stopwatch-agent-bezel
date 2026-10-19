#include <cassert>
#include <cstring>
#include <string>
#include <vector>
#include "TaskNotificationUi.h"
struct Canvas {
  struct Text {std::string value;int x,y;};
  struct Rect {int x,y,w,h;};
  std::vector<std::string> strings;
  std::vector<Text> texts;
  std::vector<Rect> rectangles;
  void fillScreen(unsigned){} void setTextFont(int){} void setTextSize(float){}
  void setTextDatum(textdatum_t){} void setTextColor(unsigned){}
  void fillRoundRect(int x,int y,int w,int h,int,unsigned){rectangles.push_back({x,y,w,h});}
  void drawRoundRect(int,int,int,int,int,unsigned){}
  void fillRect(int,int,int,int,unsigned){}
  void drawString(const char* s,int x,int y){strings.emplace_back(s);texts.push_back({s,x,y});}
};
int main(){
  using namespace task_notification;
  Card c;c.g=1;c.id=1;c.r=1;c.count=2;c.ttl=15000;c.alert=2;c.decide=true;
  std::strcpy(c.src,"codex");std::strcpy(c.kind,"approval");std::strcpy(c.state,"pending");
  std::strcpy(c.title,"Synthetic task");
  for(int i=0;i<192;++i)c.detail[i]=char('a'+i%26);
  Controller inbox;inbox.receive(c,100);
  assert(inbox.badge(420,233));assert(!inbox.badge(325,74));
  Canvas badge;task_notification::badge(badge,inbox);
  assert(badge.rectangles.size()==1);
  const auto& bounds=badge.rectangles.front();
  assert(bounds.x>390&&bounds.y+bounds.h/2==233);
  assert(inbox.badge(bounds.x,bounds.y)&&inbox.badge(bounds.x+bounds.w,bounds.y+bounds.h));
  Controller empty;assert(!empty.badge(420,233));
  for(bool toast:{false,true}){
    Controller layout;layout.receive(c,100);
    if(toast)layout.present(100,true);else layout.openInbox(100);
    Canvas frame;task_notification::render(frame,layout,110);
    bool lowerTitle=false,lowerBody=false,back=false;std::string full;
    for(const auto& text:frame.texts){
      full+=text.value;
      if(text.value==c.title)lowerTitle=text.y>=120;
      if(text.value==std::string(c.detail,36))lowerBody=text.y>=195&&text.y+5*15+7<290;
      if(text.value=="BACK")back=text.y==430;
    }
    assert(lowerTitle&&lowerBody&&back&&full.find(c.detail)!=std::string::npos);
  }
  Controller ui;ui.receive(c,100);ui.present(100,true);
  ui.press(233,233,110,true);ui.release(233,233,120);
  Action a;assert(ui.takeAction(a));c.ack=a.seq;c.alert=0;ui.receive(c,130);
  Canvas canvas;task_notification::render(canvas,ui,140);
  std::string joined;for(auto& s:canvas.strings)joined+=s;
  assert(joined.find(c.detail)!=std::string::npos);assert(joined.find("ALLOW ONCE")!=std::string::npos);
  canvas.strings.clear();ui.disconnect();task_notification::render(canvas,ui,150);
  joined.clear();for(auto& s:canvas.strings)joined+=s;
  assert(joined.find("ALLOW ONCE")==std::string::npos);assert(joined.find("OFFLINE")!=std::string::npos);
  std::puts("PASS full decision scope rendered and offline decision controls removed");
}
