// SPDX-License-Identifier: MIT
#pragma once
#include <M5GFX.h>
#include <cstdio>
#include "TaskNotification.h"

namespace task_notification {
constexpr uint16_t kInk=0xF7DF,kDim=0x9CF3,kPanel=0x1082,kAmber=0xFD20,kGreen=0x47F2,kRed=0xFA8A;
template<class Surface> void label(Surface& s,const char* text,int x,int y,uint16_t color=kInk,float size=2){
  s.setTextFont(1);s.setTextSize(size);s.setTextDatum(middle_center);s.setTextColor(color);s.drawString(text,x,y);
}
template<class Surface> void wrapped(Surface& s,const char* text,int y,unsigned columns,float size,unsigned maxRows=6){
  const std::size_t n=std::strlen(text);
  unsigned row=0;
  for(std::size_t at=0;at<n;++row){
    char line[49]={};auto count=std::min<std::size_t>(columns,n-at);
    // Prefer word boundaries without adding lines or omitting any scope bytes.
    const std::size_t reserve=columns*(maxRows-row-1);
    const std::size_t minimum=(n-at)>reserve?(n-at)-reserve:1;
    if(count<n-at)for(std::size_t i=count;i>=minimum&&i>0;--i)if(text[at+i-1]==' '){count=i;break;}
    std::memcpy(line,text+at,count);label(s,line,233,y,kInk,size);y+=size>=2?20:15;
    at+=count;
  }
}
template<class Surface> void button(Surface& s,const char* text,int x,int y,int w,uint16_t color){
  s.fillRoundRect(x,y,w,32,9,kPanel);s.drawRoundRect(x,y,w,32,9,color);label(s,text,x+w/2,y+16,color);
}
template<class Surface> void badge(Surface& s,const Controller& ui){
  if(!ui.card().count)return;
  char text[8];std::snprintf(text,sizeof(text),"N%u",ui.card().count);
  s.fillRoundRect(kBadgeX,kBadgeY,kBadgeWidth,kBadgeHeight,18,kPanel);
  s.drawRoundRect(kBadgeX,kBadgeY,kBadgeWidth,kBadgeHeight,18,kAmber);
  label(s,text,kBadgeX+kBadgeWidth/2,kBadgeY+kBadgeHeight/2,kAmber);
}
template<class Surface> void render(Surface& s,const Controller& ui,uint32_t now){
  const auto& c=ui.card();s.fillScreen(0x0000);
  const uint16_t color=!std::strcmp(c.kind,"failed")?kRed:
      (!std::strcmp(c.kind,"done")?kGreen:kAmber);
  char heading[30];std::snprintf(heading,sizeof(heading),"%s   %u NOTICES",c.src,c.count);
  const bool browsing=ui.view()==View::Inbox||ui.view()==View::Toast;
  const int offset=browsing?30:0;
  label(s,heading,233,45+offset,color);label(s,c.model,233,67+offset,kDim,1.5f);
  wrapped(s,c.title,94+offset,24,2,2);
  const char* state=!ui.linked()?"OFFLINE":c.state;
  if(ui.linked()&&!std::strcmp(c.state,"resolved")&&c.outcome[0])state=c.outcome;
  if(!std::strcmp(c.state,"pending")&&c.decide&&!ui.canDecide(now)&&!ui.holdElapsed(now))state="WAITING / EXPIRED";
  label(s,state,233,139+offset,color,1.5f);
  // Keep all 192 ASCII bytes visible; browsing uses the space freed by compact hints.
  wrapped(s,c.detail,165+offset,browsing?32:36,browsing?2:1.5f,browsing?7:6);
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
    }else label(s,!std::strcmp(c.state,"unknown")?"RESULT UNKNOWN":"Review on Mac",233,301,kDim);
    button(s,"OPEN ON MAC",100,376,266,kDim);
  }else{
    label(s,!std::strcmp(c.kind,"done")?"EXECUTION ENDED":!std::strcmp(c.kind,"failed")?"EXECUTION FAILED":"NEEDS YOU",233,350,color,1.5f);
    label(s,"UP/DOWN: BROWSE   TAP: DETAILS",233,382,kDim,1.25f);
    label(s,"LEFT: DISMISS   RIGHT: BACK",233,398,kDim,1.25f);
  }
  label(s,ui.view()==View::Confirm?"CANCEL":"BACK",233,430,kDim);
}
} // namespace task_notification
