#include <cassert>
#include <cmath>
#include <cstdint>
#include <string>
#include <vector>
#include "RobotHomeUi.h"
struct Surface {
  struct Portrait { const std::uint8_t* bytes; float x,y,scale,angle; };
  struct Text { std::string value; int x,y; };
  std::vector<Portrait> portraits;
  std::vector<Text> texts;
  unsigned effects=0;
  void drawPortrait(const std::uint8_t* bytes,std::uint32_t,float x,float y,float scale,float angle) {
    portraits.push_back({bytes,x,y,scale,angle});
  }
  void loadFont(const std::uint8_t*) {}
  void unloadFont() {}
  void setTextDatum(textdatum_t) {}
  void setTextSize(float) {}
  void setTextColor(int) {}
  int textWidth(const char* s){return std::string(s).size()*10;}
  void drawString(const char* s,int x,int y){texts.push_back({s,x,y});}
  void fillScreen(int) {}
  void fillRect(int x,int y,int w,int h,int){assert(x>=0&&y>=0&&x+w<=466&&y+h<=466);}
  void fillSmoothRoundRect(int x,int y,int w,int h,int,int c){fillRect(x,y,w,h,c);}
  void drawLine(int x,int y,int x2,int y2,int){check(x,y);check(x2,y2);++effects;}
  void drawCircle(int x,int y,int r,int){check(x-r,y-r);check(x+r,y+r);++effects;}
  void fillCircle(int x,int y,int r,int c){drawCircle(x,y,r,c);}
  void check(int x,int y){assert(x>=64&&x<=402&&y>=64&&y<=398);}
};
int main(){
  using namespace robot_home;
  assert(kCharacterCount==9&&kFullbodyCount==8);
  std::vector<const std::uint8_t*> identities;
  for(auto c:{Character::Bumblebee,Character::BumblebeeFullbody,Character::Optimus,
              Character::Jazz,Character::Hotrod,Character::Wheeljack,Character::Hound,
              Character::Ironhide,Character::Ratchet}) {
    State state;state.character=c;state.connected=true;state.batteryPercent=82;
    Surface idle;render(idle,state);
    assert(idle.portraits.size()==1&&idle.effects==0);
    const auto portrait=idle.portraits[0];
    assert(portrait.bytes&&std::fabs(portrait.scale-1.18f)<.001f);
    for(auto existing:identities)assert(existing!=portrait.bytes);
    identities.push_back(portrait.bytes);
    assert(idle.texts.size()==2&&idle.texts[0].value=="CONNECTED"&&idle.texts[0].y==44);
    assert(idle.texts[1].value=="82%"&&idle.texts[1].y==420);
    for(auto mood:{Mood::Press,Mood::Skill})
      for(unsigned ms:{0u,20u,100u,200u,300u,419u,599u,600u})
        for(auto xy:{std::pair<int,int>{0,0},{466,466},{233,233}}) {
          Surface surface;state.mood=mood;state.reactionElapsedMs=ms;state.touchX=xy.first;state.touchY=xy.second;
          render(surface,state);assert(surface.effects==0); // character responds without energy overlays
          assert(surface.portraits.size()==1);
          if(mood==Mood::Press||ms>=600||c==Character::Bumblebee)
            assert(surface.portraits[0].bytes==portrait.bytes);
          if(mood==Mood::Skill&&ms==200&&c!=Character::Bumblebee)
            assert(surface.portraits[0].bytes!=portrait.bytes); // body gesture, not a scaled idle
          assert(surface.texts[0].value=="CONNECTED"&&surface.texts[1].value=="82%");
          if(mood==Mood::Press)assert(surface.portraits[0].scale<portrait.scale);
          if(mood==Mood::Skill&&ms>=600) {
            auto end=surface.portraits[0];
            assert(end.x==portrait.x&&end.y==portrait.y&&end.scale==portrait.scale&&end.angle==0);
          }
        }
    state.mood=Mood::Idle;state.transitionProgress=0;
    Surface arrival;render(arrival,state);assert(arrival.portraits[0].scale<portrait.scale);
  }
  assert(identities.size()==9);
  State tilted;tilted.imuPose={8,10,-8,1};
  Surface tiltSurface;render(tiltSurface,tilted);
  assert(tiltSurface.portraits[0].x==243&&tiltSurface.portraits[0].y==224);
  assert(tiltSurface.portraits[0].angle==8);
  State resting;resting.imuPose={0,0,4,.95f};
  Surface restSurface;render(restSurface,resting);
  assert(restSurface.portraits[0].y==236&&restSurface.portraits[0].scale<1.18f);
  // Tap responses retain priority over the background posture transform.
  tilted.mood=Mood::Press;
  Surface pressing;render(pressing,tilted);
  assert(pressing.portraits[0].x==233&&pressing.portraits[0].angle==0);
  for(int i=1;i<kCharacterCount;++i) {
    auto hero=static_cast<Character>(i);
    for(unsigned pose=1;pose<=(i<=2?2u:1u);++pose) {
      auto action=character_art::actionFor(hero,pose);
      auto fallback=character_art::idleForAsset(action);
      assert(fallback.bytes==character_art::assetFor(hero).bytes);
    }
  }
}
