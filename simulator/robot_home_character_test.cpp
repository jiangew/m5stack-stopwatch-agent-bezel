#include <cassert>
#include <cmath>

#include "RobotHomeCharacter.h"

int main() {
  using C = robot_home::Character;
  using D = touch_gesture::Direction;

  robot_home::CharacterSelector selector;
  assert(selector.character() == C::Bumblebee);

  assert(selector.select(D::Up, 100) == C::Optimus);
  assert(selector.select(D::Up, 200) == C::Bumblebee);
  assert(selector.select(D::Down, 300) == C::Megatron);
  assert(selector.select(D::Right, 400) == C::Starscream);
  assert(selector.select(D::Right, 500) == C::Bumblebee);

  assert(selector.select(D::Left, 600) == C::Bumblebee);
  assert(std::fabs(selector.transitionProgress(500) - 0.0f) < 0.001f);
  assert(std::fabs(selector.transitionProgress(660) - 0.5f) < 0.001f);
  assert(std::fabs(selector.transitionProgress(820) - 1.0f) < 0.001f);

  assert(selector.select(D::Down, 0xFFFFFFF0u) == C::Megatron);
  assert(std::fabs(selector.transitionProgress(0x00000130u) - 1.0f) < 0.001f);

  selector.reset();
  assert(selector.character() == C::Bumblebee);
  assert(std::fabs(selector.transitionProgress(0) - 1.0f) < 0.001f);
}
