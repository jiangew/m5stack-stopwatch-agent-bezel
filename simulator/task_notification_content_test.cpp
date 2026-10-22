#include <cassert>
#include <cstring>
#include <fstream>
#include <string>
#include "TaskNotification.h"
int main(int argc,char** argv){
 if(argc==2){
   std::ifstream input(argv[1]);assert(input.good());std::string line;unsigned count=0;
   while(std::getline(input,line)){
     assert(line.size()<=512);StaticJsonDocument<2048> wire;task_notification::Card parsed;
     assert(!deserializeJson(wire,line));assert(task_notification::parse(wire.as<JsonObjectConst>(),parsed));
     assert(parsed.rich&&parsed.position>=1&&parsed.position<=parsed.count&&!parsed.decide);
     assert(task_notification::validUtf8(parsed.title,std::strlen(parsed.title))&&task_notification::validUtf8(parsed.detail,std::strlen(parsed.detail)));++count;
   }
   assert(count==6);puts("PASS Swift broker rich wire parsed by real firmware (6 Unicode/escaping fixtures)");return 0;
 }
 using namespace task_notification;
 StaticJsonDocument<2048> d;
 assert(!deserializeJson(d,R"({"v":1,"g":2,"id":3,"r":1,"src":"codex","kind":"done","title":"优化通知页布局","model":"","detail":"长正文摘录","state":"resolved","count":6,"ttl":0,"alert":1,"decide":false,"layout":2,"pos":2,"project":"stopwatch","time":"14:32","excerpted":true})"));
 Card c;assert(parse(d.as<JsonObjectConst>(),c));assert(c.rich&&c.position==2&&c.excerpted&&std::string(c.title)=="优化通知页布局");
 for(const char* bad:{"\xc0\xaf","\xed\xa0\x80","\xf4\x90\x80\x80","\xe4\xb8","bad\nline"}){d["title"]=bad;assert(!parse(d.as<JsonObjectConst>(),c));}
 d["title"]="中文";d["decide"]=true;assert(!parse(d.as<JsonObjectConst>(),c));d["decide"]=false;
 d["pos"]=7;assert(!parse(d.as<JsonObjectConst>(),c));d["pos"]=2;
 d["layout"]=3;assert(!parse(d.as<JsonObjectConst>(),c));d["layout"]=2;
 d["kind"]="approval";assert(!parse(d.as<JsonObjectConst>(),c));d["kind"]="done";
 d.remove("layout");assert(!parse(d.as<JsonObjectConst>(),c));
 d["title"]="ASCII";d["detail"]="ASCII";assert(parse(d.as<JsonObjectConst>(),c)&&!c.rich);
 puts("PASS bounded UTF-8 rich protocol, invalid encodings, positions and legacy authority isolation");
}
