// THROWAWAY: Does a 600ms character response read clearly at real Home size?
// Shared firmware Home renderer/status/font; only portrait drawing is replaced.
#include <M5GFX.h>
#include "RobotHomeUi.h"
#include <cstdio>
#include <string>
#include <vector>
#include <cmath>

struct PilotCanvas : lgfx::LGFX_Sprite {
  lgfx::LGFX_Sprite poses[3];
  int pose=0; float compression=1, lift=0;
  void drawPortrait(const std::uint8_t*,std::uint32_t,float cx,float cy,float scale,float angle) {
    setClipRect(64,64,339,335);
    poses[pose].pushRotateZoom(this,cx,cy-lift,angle,scale*compression,scale*compression,0);
    clearClipRect();
  }
};

void writePpm(lgfx::LGFX_Sprite& s,const std::string& path) {
  auto* f=std::fopen(path.c_str(),"wb");
  std::fprintf(f,"P6\n466 466\n255\n");
  std::vector<lgfx::bgr888_t> pixels(466*466);
  s.readRectRGB(0,0,466,466,pixels.data());
  for(auto& p:pixels) {const std::uint8_t rgb[]={p.R8(),p.G8(),p.B8()};std::fwrite(rgb,1,3,f);}
  std::fclose(f);
}

int main(int argc,char**argv) {
  if(argc!=2)return 1;
  std::string out=argv[1];
  for(auto hero:{"bumblebeefullbody","optimus"}) {
    PilotCanvas canvas;canvas.setColorDepth(16);canvas.createSprite(466,466);canvas.setTextWrap(false);
    for(int p=0;p<3;++p) {
      std::string path=out+"/fitted/"+hero+"-"+std::to_string(p)+".jpg";
      auto*f=std::fopen(path.c_str(),"rb");if(!f)return 2;
      std::fseek(f,0,SEEK_END);auto size=std::ftell(f);std::rewind(f);
      std::vector<std::uint8_t> jpg(size);std::fread(jpg.data(),1,size,f);std::fclose(f);
      auto& sprite=canvas.poses[p];sprite.setColorDepth(16);sprite.createSprite(300,300);sprite.setPivot(150,150);
      sprite.fillScreen(0);if(!sprite.drawJpg(jpg.data(),jpg.size(),0,0))return 3;
    }
    // 30fps: 400ms idle, 100ms press, 600ms response, 700ms idle.
    for(int i=0;i<54;++i) {
      robot_home::State s;s.connected=true;s.batteryPercent=82;
      s.character=std::string(hero)=="optimus"?robot_home::Character::Optimus:robot_home::Character::BumblebeeFullbody;
      canvas.pose=0;canvas.compression=1;canvas.lift=0;
      if(i>=12&&i<15) canvas.compression=.97f;
      if(i>=15&&i<33) {
        int t=i-15;
        if(std::string(hero)=="optimus")canvas.pose=t<4?1:(t<12?2:(t<16?1:0));
        else canvas.pose=t<4?1:(t<8?2:(t<12?1:(t<16?2:0)));
        float phase=t/18.0f;
        canvas.lift=std::sin(phase*3.14159265f)*(std::string(hero)=="optimus"?1.5f:3.5f);
      }
      robot_home::render(canvas,s);
      char suffix[32];std::snprintf(suffix,sizeof suffix,"-%03d.ppm",i);
      writePpm(canvas,out+"/frames/"+hero+suffix);
    }
  }
  std::puts("Rendered 108 RGB565 Home frames, two 600ms response pilots.");
}
