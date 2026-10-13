// SPDX-License-Identifier: MIT
#pragma once
#include <algorithm>
#include <cmath>
#include <cstdint>
#include "RobotHomeCharacter.h"
#include "RobotHomeInteraction.h"
namespace robot_home {
namespace effects {
constexpr float kTau=6.2831853f;
inline std::uint16_t tint(Character c) {
  switch(c) {
    case Character::Bumblebee:return 0xFFE0;
    case Character::BumblebeeFullbody:return 0xFFE0;
    case Character::Optimus:return 0x05FF;
    case Character::Jazz:return 0x4D9F;
    case Character::Hotrod:return 0xFC00;
    case Character::Wheeljack:return 0x07E0;
    case Character::Hound:return 0x47E8;
  }
  return 0xFFFF;
}
inline std::uint16_t fade(std::uint16_t c,float intensity) {
  const float f=std::max(.08f,std::min(1.0f,intensity));
  return (static_cast<unsigned>(((c>>11)&31)*f)<<11)|
         (static_cast<unsigned>(((c>>5)&63)*f)<<5)|
          static_cast<unsigned>((c&31)*f);
}
inline int point(float value) {return static_cast<int>(std::lround(value));}
template<class Surface>
void stroke(Surface& surface,int x,int y,int x2,int y2,int color) {
  surface.drawLine(x,y,x2,y2,color);
  surface.drawLine(x,y+1,x2,y2+1,color);
}

template<class Surface>
void render(Surface& surface,Character character,Mood mood,std::uint32_t elapsed,int touchX,int touchY) {
  if(mood!=Mood::Press&&mood!=Mood::Skill)return;
  const int cx=std::max(144,std::min(322,touchX));
  const int cy=std::max(144,std::min(320,touchY));
  const float t=std::min(1.0f,elapsed/(mood==Mood::Press?500.0f:420.0f));
  const auto color=fade(tint(character),mood==Mood::Press?.95f:1-.65f*t);
  if(mood==Mood::Press) {
    const int radius=12+point(10*t);
    // Visible in the first input frame; no need to wait for elapsed time.
    for(int i=0;i<6;++i) {
      const float a=kTau*i/6+t;
      stroke(surface,point(cx+radius*std::cos(a)),point(cy+radius*std::sin(a)),
                       point(cx+(radius+7)*std::cos(a)),point(cy+(radius+7)*std::sin(a)),color);
    }
    surface.fillCircle(cx,cy,3,color);
    return;
  }
  switch(character) {
    case Character::Bumblebee:
    case Character::BumblebeeFullbody: {
      // Jagged shoulder sparks, moving outward on both sides.
      const int spread=point(24*t);
      for(int side:{-1,1})for(int ray=0;ray<3;++ray) {
        const int x=233+side*(85+spread), y=186+ray*38;
        stroke(surface,x,y,x+side*18,y-8,color);
        stroke(surface,x+side*18,y-8,x+side*12,y+7,color);
        stroke(surface,x+side*12,y+7,x+side*32,y-1,color);
        stroke(surface,x+side*32,y-1,x+side*40,y+10,color);
      }
      break;
    }
    case Character::Optimus: {
      const int y=144+point(176*t);
      for(int dy=-2;dy<=2;++dy)stroke(surface,151,y+dy,315,y+dy,color);
      for(int side:{-1,1}) {
        const int x=233+side*100;
        stroke(surface,x,y-12,x,y+12,color);
        stroke(surface,x,y,x-side*12,y,color);
      }
      break;
    }
    case Character::Jazz: {
      const int r=14+point(58*std::sqrt(t));
      surface.drawCircle(cx,cy,r,color);
      surface.drawCircle(cx,cy,r-1,color);
      surface.drawCircle(cx,cy,std::max(3,r-16),fade(color,.7f));
      surface.drawCircle(cx,cy,std::max(3,r-32),fade(color,.5f));
      break;
    }
    case Character::Hotrod: {
      const int shift=point(34*t);
      for(int lane=0;lane<5;++lane) {
        const int y=166+lane*34;
        stroke(surface,112+shift,y,166+shift,y-12,color);
        stroke(surface,300+shift,y+14,345+shift,y+2,color);
      }
      break;
    }
    case Character::Wheeljack: {
      const int spread=point(24*t);
      for(int side:{-1,1})for(int ray=0;ray<4;++ray) {
        const int x=233+side*(58+spread), y=176+ray*36;
        stroke(surface,x,y,x+side*14,y-12,color);
        stroke(surface,x+side*14,y-12,x+side*20,y+4,color);
        stroke(surface,x+side*20,y+4,x+side*36,y-6,color);
      }
      break;
    }
    case Character::Hound: {
      const int r=16+point(54*t);
      for(int ring=1;ring<=3;++ring)
        surface.drawCircle(cx,cy,std::max(3,r*ring/3),fade(color,1.0f-.18f*(3-ring)));
      const float a=-kTau/4+kTau*t;
      stroke(surface,cx,cy,point(cx+r*std::cos(a)),point(cy+r*std::sin(a)),color);
      break;
    }
  }
}
}
}
