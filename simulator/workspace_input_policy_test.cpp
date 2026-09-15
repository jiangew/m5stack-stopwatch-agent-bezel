#include <cassert>

#include "WorkspaceInputPolicy.h"

int main() {
  using workspace_input::Control;
  using workspace_mode::Mode;
  assert(workspace_input::touchDownWakes(Mode::Codex));
  assert(!workspace_input::touchDownWakes(Mode::Super));
  assert(!workspace_input::touchDownWakes(Mode::Hermes));
  assert(!workspace_mode::isDirectional(Mode::Codex));
  assert(workspace_mode::isDirectional(Mode::Super));
  assert(workspace_mode::isDirectional(Mode::Hermes));
  for (auto from : {Mode::Codex, Mode::Super, Mode::Hermes})
    for (auto to : {Mode::Codex, Mode::Super, Mode::Hermes})
      assert(workspace_mode::silencesAgentTransitions(from, to) ==
             (from != Mode::Codex || to != Mode::Codex));

  constexpr Control allControls[] = {
      Control::SwipeUp,
      Control::SwipeRight,
      Control::SwipeDown,
      Control::SwipeLeft,
      Control::Agent,
      Control::Send,
      Control::CenterPowerHold,
      Control::LeftPhysicalButton,
      Control::RightPhysicalButton,
      Control::RedPowerButton,
  };
  for (Control control : allControls) {
    assert(workspace_input::allowed(Mode::Codex, control));
    assert(workspace_input::allowed(Mode::Home, control) ==
           workspace_input::allowed(Mode::Super, control));
    assert(workspace_input::allowed(Mode::Hermes, control) ==
           workspace_input::allowed(Mode::Super, control));
  }

  assert(workspace_input::allowed(Mode::Super, Control::SwipeUp));
  assert(workspace_input::allowed(Mode::Super, Control::SwipeRight));
  assert(workspace_input::allowed(Mode::Super, Control::SwipeDown));
  assert(workspace_input::allowed(Mode::Super, Control::SwipeLeft));
  assert(workspace_input::allowed(Mode::Super, Control::CenterPowerHold));
  assert(workspace_input::allowed(Mode::Super, Control::RedPowerButton));

  assert(!workspace_input::allowed(Mode::Super, Control::Agent));
  assert(!workspace_input::allowed(Mode::Super, Control::Send));
  assert(!workspace_input::allowed(Mode::Super,
                                   Control::LeftPhysicalButton));
  assert(!workspace_input::allowed(Mode::Super,
                                   Control::RightPhysicalButton));
}
