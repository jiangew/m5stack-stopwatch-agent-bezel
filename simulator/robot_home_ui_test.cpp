#include <cassert>
#include <string>
#include <vector>
#include "RobotHomeUi.h"
struct Surface {
  struct Text {std::string s;int x,y;};std::vector<Text> texts;
  std::vector<int> geometry;
  void loadFont(const std::uint8_t*){} void unloadFont(){}
  void setTextDatum(textdatum_t){} void setTextSize(float){}
  void setTextColor(int){}
  int textWidth(const char* s){return int(std::string(s).size())*10;}
  void drawString(const char* s,int x,int y){texts.push_back({s,x,y});}
  void fillScreen(int){}
  void fillTriangle(int a,int b,int c,int d,int e,int f,int){
    geometry.insert(geometry.end(),{a,b,c,d,e,f});
    for(int v:{a,b,c,d,e,f})assert(v>=0&&v<466);
    for(auto p:{robot_home::Point{a,b},robot_home::Point{c,d},robot_home::Point{e,f}})
      assert((p.x-233)*(p.x-233)+(p.y-233)*(p.y-233)<=233*233);
  }
  void fillRect(int x,int y,int w,int h,int){assert(x>=0&&y>=0&&x+w<=466&&y+h<=466);}
  void fillSmoothRoundRect(int x,int y,int w,int h,int,int){fillRect(x,y,w,h,0);}
};
int main(){
  Surface idle,talking;robot_home::State probe;probe.nowMs=100;
  robot_home::render(idle,probe);probe.mood=robot_home::Mood::Talking;
  robot_home::render(talking,probe);assert(idle.geometry!=talking.geometry);
  std::vector<std::vector<int>> fingerprints;
  for(auto character:{robot_home::Character::Bumblebee,
                      robot_home::Character::Optimus,
                      robot_home::Character::Megatron,
                      robot_home::Character::Starscream}){
    Surface surface;robot_home::State state;state.character=character;
    state.transitionProgress=1.0f;robot_home::render(surface,state);
    fingerprints.push_back(surface.geometry);
  }
  for(std::size_t i=0;i<fingerprints.size();++i)
    for(std::size_t j=i+1;j<fingerprints.size();++j)
      assert(fingerprints[i]!=fingerprints[j]);
  for(bool charging:{false,true})for(unsigned now=0;now<5200;now+=50)
  for(int battery:{-1,0,9,78,100})
  for(auto character:{robot_home::Character::Bumblebee,
                      robot_home::Character::Optimus,
                      robot_home::Character::Megatron,
                      robot_home::Character::Starscream})
  for(float transition:{0.0f,0.5f,1.0f})
  for(auto mood:{robot_home::Mood::Idle,robot_home::Mood::Talking}){
    Surface s;robot_home::State state;state.batteryPercent=battery;state.mood=mood;state.nowMs=now;state.charging=charging;
    state.character=character;state.transitionProgress=transition;
    robot_home::render(s,state);
    bool found=false;
    for(auto& t:s.texts)if(t.s.find('%')!=std::string::npos){found=true;assert(t.y==395);int left=t.x-30;int right=t.x+s.textWidth(t.s.c_str());assert((left+right)/2==233);}
    assert(found);
  }
}
