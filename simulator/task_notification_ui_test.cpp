#include <cassert>
#include <cstring>
#include <string>
#include <vector>
#include "TaskNotificationUi.h"
#include "WorkspacePalette.h"
struct Canvas {
  struct Text {std::string value;int x,y;float size;textdatum_t datum;const std::uint8_t* font;unsigned color;};
  struct Rect {int x,y,w,h;unsigned color;};
  struct Circle {int x,y,r;unsigned color;};
  std::vector<Circle> circles;
  std::vector<std::string> strings;
  std::vector<Text> texts;
  std::vector<Rect> rectangles;
  const std::uint8_t* font=nullptr;
  void loadFont(const std::uint8_t* f){font=f;}
  void unloadFont(){font=nullptr;}
  void setFont(const lgfx::IFont* f){font=reinterpret_cast<const std::uint8_t*>(f);}
  int textWidth(const char* s){int width=0;for(std::size_t i=0;i<std::strlen(s);){unsigned n=task_notification::utf8Length(static_cast<unsigned char>(s[i]));width+=n>1?24:15;i+=n;}return width;}
  float textSize=1;
  textdatum_t datum=middle_center;
  void fillScreen(unsigned){} void setTextFont(int){} void setTextSize(float size){textSize=size;}
  unsigned textColor=0;
  void setTextDatum(textdatum_t value){datum=value;} void setTextColor(unsigned color){textColor=color;}
  void fillRoundRect(int x,int y,int w,int h,int,unsigned color){rectangles.push_back({x,y,w,h,color});}
  void drawRoundRect(int,int,int,int,int,unsigned){}
  void fillRect(int,int,int,int,unsigned){}
  void fillSmoothCircle(int x,int y,int r,unsigned color){circles.push_back({x,y,r,color});}
  void drawString(const char* s,int x,int y){strings.emplace_back(s);assert(font&&textSize>0);texts.push_back({s,x,y,textSize,datum,font,textColor});}
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
    assert(badge.texts[0].x==388&&badge.texts[0].y==232&&badge.texts[0].datum==middle_center);
    assert(badge.circles.size()==2&&badge.circles[0].r==45&&badge.circles[1].r==42);
    for(auto circle:badge.circles)assert(circle.x==388&&circle.y==232);
    assert(badge.circles[1].color==workspace_palette::rgb565(0xFFC857));
    assert(badge.texts[0].color==workspace_palette::rgb565(0x172554));
    assert(badge.texts[0].size==1&&badge.texts[0].font[11]==36); // native36px VLW, no scaling
  }
  for(int x:{332,388,444})for(int y:{176,232,288}) {
    assert(inbox.badge(x,y));
    assert((x-233)*(x-233)+(y-233)*(y-233)<233*233);
  }
  assert(!inbox.badge(331,232)&&!inbox.badge(445,232));
  assert(!inbox.badge(388,175)&&!inbox.badge(388,289));
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
  auto checkFooter=[](const Canvas& frame){
    unsigned back=0,open=0,hints=0;int firstY=0,leftY=0,rightY=0;unsigned colors[2]={};
    assert(frame.rectangles.size()==2);
    for(unsigned i=0;i<2;++i){const auto& r=frame.rectangles[i];
      assert(r.x==(i?248:78)&&r.y==344&&r.w==140&&r.h==48&&r.color!=0);colors[i]=r.color;
      for(int x:{r.x,r.x+r.w})for(int y:{r.y,r.y+r.h})assert((x-233)*(x-233)+(y-233)*(y-233)<223*223);
    }
    assert(colors[0]!=colors[1]);
    for(const auto& t:frame.texts){
      assert(t.value!="MORE ON MAC"&&t.value!="OPEN ON MAC"&&t.value!="TAP: DETAILS");
      if(t.value=="BACK"){++back;assert(t.x==148&&t.y==368&&t.font==font_data::kSpaceMono22Vlw);}
      if(t.value=="OPEN"){++open;assert(t.x==318&&t.y==368&&t.font==font_data::kSpaceMono22Vlw);}
      if(t.value=="UP/DOWN: BROWSE"||t.value=="LEFT: DISMISS"||t.value=="RIGHT: BACK"){
        assert(t.font[8]==0&&t.font[9]==0&&t.font[10]==0&&t.font[11]==14&&t.size==1);++hints;
        if(t.value=="UP/DOWN: BROWSE"){firstY=t.y;assert(t.x==233&&t.datum==middle_center);}
        else {assert(t.datum==middle_left);if(t.value=="LEFT: DISMISS"){leftY=t.y;assert(t.x==125);}else{rightY=t.y;assert(t.x==253);}}
      }
    }
    assert(back==1&&open==1&&hints==3&&firstY==408&&leftY==426&&rightY==426);
  };
  Card readOnly=c;readOnly.decide=false;
  Controller detail;detail.receive(readOnly,100);detail.present(100,true);
  detail.press(233,233,110,true);detail.release(233,233,120);
  Canvas largeDetail;task_notification::render(largeDetail,detail,130);checkFooter(largeDetail);
  bool ellipsis=false;unsigned rows=0;
  for(const auto& t:largeDetail.texts)if(t.y>=201&&t.y<=313){
    assert(t.x==233&&t.datum==middle_center&&t.font==font_data::kSpaceMono22Vlw);
    ++rows;ellipsis=ellipsis||t.value.find("...")!=std::string::npos;
  }
  assert(rows==5&&ellipsis); // read-only excerpt stays above buttons; native scope below remains complete
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
  for(const auto& item:std::vector<std::pair<const char*,const char*>>{{"codex","Codex"},{"deepseek","DSH"},{"super","Super"}}){
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
  Card rich=c;rich.decide=false;rich.rich=true;rich.position=2;rich.count=6;rich.excerpted=true;
  std::strcpy(rich.kind,"done");std::strcpy(rich.title,"优化通知页布局");std::strcpy(rich.detail,"Result excerpt");std::strcpy(rich.project,"stopwatch");std::strcpy(rich.time,"14:32");
  Controller richUi;richUi.receive(rich,200);richUi.openInbox(210);Canvas richFrame;render(richFrame,richUi,220);
  assert(richFrame.strings[0]=="Codex   2/6");
  assert(richFrame.texts[1].y-richFrame.texts[0].y==28);
  assert(richFrame.texts[2].y-richFrame.texts[1].y==28);
  checkFooter(richFrame);
  bool nativeBody=false;
  for(const auto& text:richFrame.texts)if(text.value=="Result excerpt")nativeBody=text.font==font_data::kSpaceMono22Vlw&&text.size==1;
  assert(nativeBody);
  Card chinese=rich;std::string body;for(int i=0;i<60;++i)body+="中";
  std::strcpy(chinese.detail,body.c_str());
  Controller chineseUi;chineseUi.receive(chinese,200);chineseUi.openInbox(210);
  Canvas chineseFrame;render(chineseFrame,chineseUi,220);
  int lastY=0;unsigned bodyRows=0;
  for(const auto& text:chineseFrame.texts)if(text.y>=201&&text.y<=333){
    assert(text.x==233&&text.datum==middle_center);
    assert(text.size>0.91f&&text.size<0.92f);
    if(lastY)assert(text.y-lastY==28);
    lastY=text.y;++bodyRows;
    assert(text.y+11<340); // clear of the button row
  }
  assert(bodyRows>1);

  assert(std::find(richFrame.strings.begin(),richFrame.strings.end(),"TURN ENDED")!=richFrame.strings.end());
  assert(std::find(richFrame.strings.begin(),richFrame.strings.end(),"MORE ON MAC")==richFrame.strings.end());
  assert(std::find(richFrame.strings.begin(),richFrame.strings.end(),"pending")==richFrame.strings.end());
  for(const auto& item:std::vector<std::pair<const char*,const char*>>{{"approval","WAITING ON MAC"},{"input","WAITING FOR INPUT"},{"done","TURN ENDED"}}){
    Card dsh=rich;std::strcpy(dsh.src,"deepseek");std::strcpy(dsh.kind,item.first);std::strcpy(dsh.state,"pending");
    Controller dshUi;dshUi.receive(dsh,200);dshUi.openInbox(210);Canvas frame;render(frame,dshUi,220);
    assert(frame.strings[0]=="DSH   2/6");
    assert(std::find(frame.strings.begin(),frame.strings.end(),item.second)!=frame.strings.end());
    assert(std::find(frame.strings.begin(),frame.strings.end(),"ALLOW ONCE")==frame.strings.end());
    for(const char* verdict:{"allowed","declined","answered","cancelled"}){
      std::strcpy(dsh.state,"resolved");std::strcpy(dsh.outcome,verdict);
      if(std::strcmp(dsh.kind,"done"))assert(std::strcmp(richStatus(dsh),"CLEARED"));
    }
    dsh.outcome[0]=0;
    if(std::strcmp(dsh.kind,"done"))assert(!std::strcmp(richStatus(dsh),"CLEARED"));
  }
  Card stopped=rich;std::strcpy(stopped.kind,"failed");std::strcpy(stopped.terminalReason,"aborted");assert(!std::strcmp(richStatus(stopped),"INTERRUPTED"));
  std::strcpy(stopped.terminalReason,"blocked");assert(!std::strcmp(richStatus(stopped),"BLOCKED"));
  std::strcpy(stopped.terminalReason,"max-tokens");assert(!std::strcmp(richStatus(stopped),"LIMIT REACHED"));
  for(const char* source:{"codex","deepseek"}){
    Card model=rich;std::strcpy(model.src,source);std::strcpy(model.model,"native-model-v4");
    Controller modelUi;modelUi.receive(model,200);modelUi.openInbox(210);Canvas frame;render(frame,modelUi,220);
    assert(frame.texts[1].value=="native-model-v4 / 14:32");
    if(!std::strcmp(source,"codex")){
      model.modelConfigured=true;Controller configuredUi;configuredUi.receive(model,200);configuredUi.openInbox(210);Canvas configured;render(configured,configuredUi,220);
      assert(configured.texts[1].value=="native-model-v4 / 14:32");model.modelConfigured=false;
    }
    model.model[0]=0;Controller unknownUi;unknownUi.receive(model,200);unknownUi.openInbox(210);Canvas missing;render(missing,unknownUi,220);
    assert(missing.texts[1].value=="模型未提供 / 14:32");
  }
  Card wide=rich;std::strcpy(wide.src,"super");std::strcpy(wide.project,"abcdefghijklmnopqrstuvwxyz123456");
  Controller wideUi;wideUi.receive(wide,200);wideUi.openInbox(210);Canvas wideFrame;render(wideFrame,wideUi,220);
  const auto& context=wideFrame.texts[1];assert(context.y==92&&wideFrame.textWidth(context.value.c_str())<=360);
  assert(context.value.find("...")!=std::string::npos&&context.value.find("14:32")!=std::string::npos);
  Canvas dense;assert(richWrapped(dense,"abcdefghijklmnopqrs abcdefghijklmnopqrs abcdefghijklmnopqrs abcdefghijklmnopqrs abcdefghijklmnopqrs abcdefghijklmnopqrs abcdefghi",201,6));
  assert(dense.texts.size()==6&&dense.texts.back().value.find("...")!=std::string::npos);
  Canvas words;richWrapped(words,"Alpha bravo charlie delta echo foxtrot",195,6);
  assert(words.texts.size()==2&&words.texts[0].value=="Alpha bravo charlie");
  for(const auto& line:words.texts)assert(words.textWidth(line.value.c_str())<=360);
  Canvas mixed;richWrapped(mixed,"优化 Codex 通知 / UI 2026",124,2);
  std::string combined;for(const auto& line:mixed.texts)combined+=line.value;
  assert(combined=="优化 Codex 通知 / UI 2026");
  std::puts("PASS full decision scope rendered and offline decision controls removed");
}
