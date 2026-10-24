#include <cassert>
#include <set>
#include "RobotHomeCharacter.h"

int main() {
  using C = robot_home::Character;
  using D = touch_gesture::Direction;
  const std::set<C> up{C::BumblebeeFullbody,C::Optimus,C::Wheeljack,
                       C::Hound,C::Ironhide,C::Ratchet};
  const std::set<C> down{C::Megatron,C::Starscream,C::Shockwave,
                         C::Thundercracker,C::Blitzwing,C::Astrotrain};
  for (auto direction : {D::Up,D::Down}) {
    const auto& expected = direction == D::Up ? up : down;
    std::set<C> reached;
    for (unsigned sample=0;sample<120;++sample) {
      robot_home::CharacterSelector selector;
      auto value=selector.select(direction,0,[sample]{return sample;});
      assert(expected.count(value)==1);
      reached.insert(value);
      assert(selector.select(direction,1,[sample]{return sample;})!=value);
      assert(selector.select(D::Right,2,[]{return 0u;})==C::Bumblebee);
    }
    assert(reached==expected);
  }
}
