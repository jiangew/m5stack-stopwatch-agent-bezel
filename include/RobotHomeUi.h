// SPDX-License-Identifier: MIT
#pragma once
#include <cmath>
#include <cstdio>
#include <initializer_list>
#include "RobotHomeInteraction.h"
#include "SuperWorkspaceUi.h"
namespace robot_home {
struct State {
  Mood mood=Mood::Idle;std::uint32_t nowMs=0;
  int batteryPercent=-1;bool charging=false,connected=false;
  super_workspace::PowerOverlay powerOverlay=super_workspace::PowerOverlay::None;
  float powerHoldProgress=0;
};
struct Point{int x,y;};
template<class Surface>void render(Surface& s,const State& state){
  constexpr int yellow=0xFE67,light=0xFF30,dark=0x2146,blue=0x7F5F,metal=0x9D78,muted=0x8C92;
  s.fillScreen(0);
  const float phase=(state.nowMs%4400)/4400.0f*6.2831853f;
  const int bob=int(std::sin(phase)*3);
  const float tilt=state.mood==Mood::Happy?std::sin((state.nowMs%700)/700.0f*6.2831853f)*0.10f:0;
  auto point=[&](Point p){float x=p.x-233,y=p.y-225;return Point{233+int(x*std::cos(tilt)-y*std::sin(tilt)),225+bob+int(x*std::sin(tilt)+y*std::cos(tilt))};};
  auto poly=[&](std::initializer_list<Point> pts,int color){auto it=pts.begin();Point first=point(*it++),previous=point(*it++);for(;it!=pts.end();++it){Point next=point(*it);s.fillTriangle(first.x,first.y,previous.x,previous.y,next.x,next.y,color);previous=next;}};
  poly({{115,119},{133,119},{157,162},{130,172}},yellow);
  poly({{351,119},{333,119},{309,162},{336,172}},yellow);
  poly({{96,184},{118,184},{120,254},{92,241}},dark);
  poly({{370,184},{348,184},{346,254},{374,241}},dark);
  poly({{116,191},{128,153},{155,126},{191,111},{275,111},{311,126},{338,153},{350,191},{345,259},{317,295},{279,312},{187,312},{149,295},{121,259}},yellow);
  poly({{211,111},{255,111},{249,176},{217,176}},dark);
  poly({{226,111},{240,111},{240,155},{226,155}},0x52AA);
  poly({{141,162},{192,133},{199,162},{150,182},{130,205}},light);
  poly({{325,162},{274,133},{267,162},{316,182},{336,205}},light);
  poly({{137,189},{191,168},{218,184},{248,184},{275,168},{329,189},{320,249},{285,286},{181,286},{146,249}},dark);
  poly({{140,181},{192,167},{218,184},{203,198},{150,194}},light);
  poly({{326,181},{274,167},{248,184},{263,198},{316,194}},light);
  const bool blink=state.mood==Mood::Idle&&(state.nowMs%5200)>2250&&(state.nowMs%5200)<2380;
  for(int dx:{0,112}){
    if(state.mood==Mood::Happy){
      poly({{155+dx,225},{175+dx,203},{181+dx,211},{162+dx,231}},blue);
      poly({{175+dx,203},{183+dx,203},{204+dx,225},{197+dx,231}},blue);
    }else if(state.mood==Mood::Sleep||blink){
      poly({{153+dx,223},{177+dx,230},{203+dx,223},{203+dx,230},{177+dx,237},{153+dx,230}},blue);
    }else if(state.mood==Mood::Surprise){
      poly({{156+dx,197},{166+dx,190},{191+dx,190},{201+dx,197},{201+dx,231},{191+dx,241},{166+dx,241},{156+dx,231}},blue);
    }else{
      poly({{153+dx,207},{176+dx,201},{202+dx,211},{197+dx,231},{173+dx,236},{155+dx,225}},blue);
    }
  }
  poly({{220,210},{246,210},{253,245},{233,255},{213,245}},0x73EF);
  poly({{175,248},{208,239},{233,254},{258,239},{291,248},{285,281},{261,299},{205,299},{181,281}},metal);
  poly({{198,256},{215,262},{251,262},{268,256},{266,263},{252,269},{214,269},{200,263}},dark);
  poly({{204,275},{262,275},{258,280},{208,280}},dark);
  poly({{218,285},{248,285},{244,290},{222,290}},dark);
  poly({{128,230},{148,241},{166,277},{179,294},{157,284},{136,265}},light);
  poly({{338,230},{318,241},{300,277},{287,294},{309,284},{330,265}},light);
  poly({{208,306},{258,306},{249,319},{217,319}},dark);
  s.loadFont(dashboard::font_data::kSpaceMono18Vlw);
  super_workspace::drawText(s,state.connected?"CONNECTED":"OFFLINE",233,64,middle_center,state.connected?0x8ED6:muted);
  const char* mood="READY WHEN YOU ARE";
  switch(state.mood){case Mood::Happy:mood="HEY, PARTNER!";break;case Mood::Surprise:mood="OH! HELLO!";break;case Mood::Sleep:mood="RECHARGING...";break;case Mood::Connect:mood="CONNECT MAC";break;default:break;}
  super_workspace::drawText(s,mood,233,357,middle_center,0xDF14);
  if(state.mood==Mood::Sleep)super_workspace::drawText(s,"z",337,135,middle_center,blue);
  char battery[8];if(state.batteryPercent<0)std::snprintf(battery,sizeof battery,"--%%");else std::snprintf(battery,sizeof battery,"%d%%",std::min(100,state.batteryPercent));
  const int width=s.textWidth(battery),left=233-(30+width)/2;
  const int color=state.batteryPercent>=0&&state.batteryPercent<=15?0xFB29:muted;
  s.fillSmoothRoundRect(left,389,20,12,2,color);s.fillRect(left+20,393,2,4,color);
  s.fillRect(left+2,391,16,8,0);
  if(state.charging)s.fillRect(left+9,390,3,10,yellow);
  else if(state.batteryPercent>0)s.fillRect(left+3,392,std::max(1,14*std::min(100,state.batteryPercent)/100),6,color);
  super_workspace::drawText(s,battery,left+30,395,middle_left,color);
  s.unloadFont();
  if(state.powerOverlay!=super_workspace::PowerOverlay::None){super_workspace::State overlay;overlay.powerOverlay=state.powerOverlay;overlay.powerHoldProgress=state.powerHoldProgress;super_workspace::drawPowerOverlay(s,overlay);}
}
}
