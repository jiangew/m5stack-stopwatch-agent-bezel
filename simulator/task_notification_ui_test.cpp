#include <cassert>
#include <cstring>
#include <string>
#include <vector>
#include "TaskNotificationUi.h"
struct Canvas {
  std::vector<std::string> strings;
  void fillScreen(unsigned){} void setTextFont(int){} void setTextSize(float){}
  void setTextDatum(textdatum_t){} void setTextColor(unsigned){}
  void fillRoundRect(int,int,int,int,int,unsigned){}
  void drawRoundRect(int,int,int,int,int,unsigned){}
  void fillRect(int,int,int,int,unsigned){}
  void drawString(const char* s,int,int){strings.emplace_back(s);}
};
int main(){
  using namespace task_notification;
  Card c;c.g=1;c.id=1;c.r=1;c.count=2;c.ttl=15000;c.alert=2;c.decide=true;
  std::strcpy(c.src,"codex");std::strcpy(c.kind,"approval");std::strcpy(c.state,"pending");
  std::strcpy(c.title,"Synthetic task");
  for(int i=0;i<192;++i)c.detail[i]=char('a'+i%26);
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
