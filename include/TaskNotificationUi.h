// SPDX-License-Identifier: MIT
#pragma once
#include <M5GFX.h>
#include <cstdio>
#include "TaskNotification.h"
#include "SpaceMonoVlw.h"
#include "NotificationFonts.h"

namespace task_notification {
constexpr uint16_t kInk=0xF7DF,kDim=0x9CF3,kPanel=0x1082,kAmber=0xFD20,kGreen=0x47F2,kRed=0xFA8A;
inline bool hasUnicode(const char* text){for(;*text;++text)if(static_cast<unsigned char>(*text)>=128)return true;return false;}
template<class Surface> void selectFont(Surface& s,float size,bool cjk){
  if(cjk)s.setFont(size>=2 ? &lgfx::fonts::efontCN_24 : &lgfx::fonts::efontCN_16);
  else s.loadFont(size>=4 ? dashboard::font_data::kSpaceMono46Vlw
      : size>=2.5f ? font_data::kSpaceMono24Vlw
      : size>=2 ? font_data::kSpaceMono22Vlw
      : size>=1.75f ? dashboard::font_data::kSpaceMono18Vlw : font_data::kSpaceMono15Vlw);
  s.setTextSize(1);
}
template<class Surface> void label(Surface& s,const char* text,int x,int y,uint16_t color=kInk,float size=2,textdatum_t datum=middle_center){
  selectFont(s,size,hasUnicode(text));s.setTextDatum(datum);s.setTextColor(color);s.drawString(text,x,y);s.unloadFont();
}
// Preserve event time while fitting the project to the circular screen chord.
template<class Surface> void richContext(Surface& s,const char* project,const char* time,int y){
  const bool cjk=hasUnicode(project);selectFont(s,1.75f,cjk);
  char name[33],line[48];std::snprintf(name,sizeof(name),"%s",project);
  std::size_t used=std::strlen(name);bool clipped=false;
  while(true){
    std::snprintf(line,sizeof(line),"%s%s%s%s",name,clipped?"...":"",used&&time[0]?" / ":"",time);
    if(s.textWidth(line)<=360||!used)break;
    do {--used;}while(used&&(static_cast<unsigned char>(name[used])&0xc0)==0x80);
    name[used]=0;clipped=true;
  }
  s.setTextDatum(middle_center);s.setTextColor(kDim);s.drawString(line,233,y);s.unloadFont();
}
// Pixel-measured UTF-8 wrapping, only for read-only rich presentation.
template<class Surface> bool richWrapped(Surface& s,const char* text,int y,unsigned rows){
  const bool cjk=hasUnicode(text);const auto n=std::strlen(text);std::size_t at=0;
  selectFont(s,2.5f,cjk);s.setTextDatum(middle_center);s.setTextColor(kInk);
  for(unsigned row=0;row<rows&&at<n;++row){
    char line[193]={};std::size_t used=0;
    while(at+used<n){
      const auto step=utf8Length(static_cast<unsigned char>(text[at+used]));
      if(!step||used+step>=sizeof(line))break;
      std::memcpy(line+used,text+at+used,step);line[used+step]=0;
      if(s.textWidth(line)>360&&used){line[used]=0;break;}
      used+=step;
    }
    // Prefer an ASCII word boundary; a CJK sequence can break at any codepoint.
    if(at+used<n && text[at+used]!=' ' && used && static_cast<unsigned char>(text[at+used-1])<128){
      for(std::size_t i=used;i>0;--i)if(text[at+i-1]==' '){used=i-1;line[used]=0;break;}
    }
    const auto consumed=used;
    if(row+1==rows&&at+used<n){
      while(used){
        std::strcpy(line+used,"...");if(s.textWidth(line)<=360)break;
        do {--used;}while(used&&(static_cast<unsigned char>(line[used])&0xc0)==0x80);
      }
      std::strcpy(line+used,"...");
    }
    s.drawString(line,233,y);at+=consumed;
    while(at<n&&text[at]==' ')++at;
    y+=26;
  }
  s.unloadFont();return at<n;
}
template<class Surface> void wrapped(Surface& s,const char* text,int y,unsigned columns,float size,unsigned maxRows=6,int left=-1,int lineStep=0){
  const std::size_t n=std::strlen(text);
  unsigned row=0;
  for(std::size_t at=0;at<n;++row){
    char line[49]={};auto count=std::min<std::size_t>(columns,n-at);
    // Prefer word boundaries without adding lines or omitting any scope bytes.
    const std::size_t reserve=columns*(maxRows-row-1);
    const std::size_t minimum=(n-at)>reserve?(n-at)-reserve:1;
    if(count<n-at)for(std::size_t i=count;i>=minimum&&i>0;--i)if(text[at+i-1]==' '){count=i;break;}
    std::memcpy(line,text+at,count);
    label(s,line,left>=0?left:233,y,kInk,size,left>=0?middle_left:middle_center);y+=lineStep>0?lineStep:(size>=2.5f?24:size>=2?20:15);
    at+=count;
  }
}
template<class Surface> void button(Surface& s,const char* text,int x,int y,int w,uint16_t color,float size=2){
  s.fillRoundRect(x,y,w,32,9,kPanel);s.drawRoundRect(x,y,w,32,9,color);label(s,text,x+w/2,y+16,color,size);
}
// Keep the large disc quiet against Home's black background; the orange-red
// count carries the contrast instead of a bright fill or outline.
constexpr uint16_t kBadgeFill=0x10C5,kBadgeEdge=0x0863,kBadgeText=0xFB27;
template<class Surface> void badge(Surface& s,const Controller& ui){
  if(!ui.card().count)return;
  char text[8];std::snprintf(text,sizeof(text),"%u",ui.card().count);
  s.fillSmoothCircle(kBadgeCenterX,kBadgeCenterY,kBadgeRadius,kBadgeEdge);
  s.fillSmoothCircle(kBadgeCenterX,kBadgeCenterY,kBadgeRadius-1,kBadgeFill);
  label(s,text,kBadgeCenterX,kBadgeCenterY,kBadgeText,4.f);
}
inline const char* sourceName(const char* source){
  if(!std::strcmp(source,"codex"))return "Codex";
  if(!std::strcmp(source,"deepseek"))return "DSH";
  if(!std::strcmp(source,"super"))return "Super";
  if(!std::strcmp(source,"hermes"))return "Hermes";
  return source;
}
// Only canonicalize known generated labels; task content remains verbatim.
inline const char* displayTitle(const Card& card){
  if(!std::strcmp(card.src,"super")){
    if(!std::strcmp(card.title,"SUPER task"))return "Super task";
    if(!std::strcmp(card.title,"SUPER needs input"))return "Super needs input";
  }
  return card.title;
}
template<class Surface> void render(Surface& s,const Controller& ui,uint32_t now){
  const auto& c=ui.card();s.fillScreen(0x0000);
  const uint16_t color=!std::strcmp(c.kind,"failed")?kRed:
      (!std::strcmp(c.kind,"done")?kGreen:kAmber);
  char heading[30];
  if(c.rich)std::snprintf(heading,sizeof(heading),"%s   %u/%u",sourceName(c.src),c.position,c.count);
  else std::snprintf(heading,sizeof(heading),"%s   %u NOTICES",sourceName(c.src),c.count);
  const bool browsing=ui.view()==View::Inbox||ui.view()==View::Toast;
  const bool reading=browsing||(ui.view()==View::Detail&&!c.decide);
  const int offset=reading?30:0;
  label(s,heading,233,45+offset,color,reading?2.5f:2.f);
  if(c.rich){
    if(c.project[0]||c.time[0])richContext(s,c.project,c.time,67+offset);
    richWrapped(s,c.title,90+offset,2);
  }else{
    if(c.model[0])label(s,c.model,233,67+offset,kDim,reading?1.75f:1.5f);
    wrapped(s,displayTitle(c),94+offset,24,reading?2.5f:2.f,2);
  }
  const char* state=!ui.linked()?"OFFLINE":c.state;
  if(ui.linked()&&!std::strcmp(c.state,"resolved")&&c.outcome[0])state=c.outcome;
  if(!std::strcmp(c.state,"pending")&&c.decide&&!ui.canDecide(now)&&!ui.holdElapsed(now))state="WAITING / EXPIRED";
  if(c.rich&&ui.linked())state=!std::strcmp(c.kind,"done")?(!std::strcmp(c.src,"codex")?"TURN ENDED":"COMPLETED"):"FAILED";
  label(s,state,233,(c.rich?145:139)+offset,color,reading?2.f:1.5f);
  // Keep all 192 ASCII bytes visible at the larger reading size: eight rows
  // of 24 columns, with dedicated space below for controls.
  // Browsing keeps all eight rows clear of the raised compact hints.
  if(c.rich){
    const bool clipped=richWrapped(s,c.detail,171+offset,6);
    if(c.excerpted||clipped)label(s,"MORE ON MAC",233,355,kDim,1.5f);
  }else wrapped(s,c.detail,165+offset,reading?24:36,reading?2.5f:1.5f,reading?8:6,-1,browsing?23:0);
  if(ui.view()==View::Confirm){
    const char* selected=ui.selection();
    if(!std::strcmp(selected,"allow_once"))selected="ALLOW ONCE";
    else if(!std::strcmp(selected,"decline"))selected="DECLINE";
    else if(!std::strncmp(selected,"choose",6)){const unsigned i=selected[6]-'0';if(i<c.optionCount)selected=c.options[i];}
    label(s,selected,233,275,kAmber);button(s,"HOLD 800ms",90,301,286,kAmber);
    const int progress=static_cast<int>(266.0f*ui.holdElapsed(now)/kConfirmMs);
    s.fillRect(100,341,266,5,kPanel);if(progress)s.fillRect(100,341,progress,5,kAmber);
    label(s,"Fresh hold confirms once",233,372,kDim,1.5f);
  }else if(ui.view()==View::Submitting){
    label(s,"SUBMITTING",233,298,kAmber);label(s,"Waiting for native result",233,327,kDim,1.5f);
  }else if(ui.view()==View::Detail){
    if(ui.canDecide(now)){
      if(c.optionCount){for(unsigned i=0;i<c.optionCount;++i)button(s,c.options[i],70,264+36*i,326,color);}
      else{button(s,"ALLOW ONCE",60,290,167,kGreen);button(s,"DECLINE",239,290,167,kRed);}
    }else if(!reading)label(s,!std::strcmp(c.state,"unknown")?"RESULT UNKNOWN":"Review on Mac",233,301,kDim);
    button(s,"OPEN ON MAC",100,376,266,kDim,reading?2.5f:2.f);
  }else{
    // Align each column independently while retaining the compact two-row footer.
    label(s,"UP/DOWN: BROWSE",88,378,kDim,1.5f,middle_left);
    label(s,"LEFT: DISMISS",88,395,kDim,1.5f,middle_left);
    label(s,"TAP: DETAILS",264,378,kDim,1.5f,middle_left);
    label(s,"RIGHT: BACK",264,395,kDim,1.5f,middle_left);
  }
  label(s,ui.view()==View::Confirm?"CANCEL":"BACK",233,430,kDim,reading?2.5f:2.f);
}
} // namespace task_notification
