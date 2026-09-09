#include <cassert>
#include <initializer_list>
#include "WorkspaceCenterTap.h"

int main() {
  workspace_input::CenterTap tap;
  tap.begin(233, 233, 100, true);
  assert(tap.finish(233, 233, 599, 48));
  assert(!tap.finish(233, 233, 599, 48));
  tap.begin(233, 233, 100, true);
  assert(!tap.finish(233, 233, 600, 48));
  for (int edge : {143, 322}) {
    tap.begin(edge, 233, 0, true);
    assert(!tap.finish(233, 233, 100, 48));
    tap.begin(233, 233, 0, true);
    assert(!tap.finish(edge, 233, 100, 48));
  }
  tap.begin(233, 233, 0, true);
  tap.move(281, 233, 48);
  assert(!tap.finish(233, 233, 100, 48));
  tap.begin(233, 233, 0, false);
  assert(!tap.finish(233, 233, 100, 48));
  tap.begin(233, 233, 0, true);
  tap.cancel();
  assert(!tap.finish(233, 233, 100, 48));
  tap.begin(233, 233, 0xFFFFFFF0u, true);
  assert(tap.finish(234, 234, 100, 48));
}
