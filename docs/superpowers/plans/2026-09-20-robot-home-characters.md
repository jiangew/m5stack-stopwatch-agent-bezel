# Robot Home Cinematic Characters Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Robot Home's expression swipes with four locally rendered, cinematic robot portraits while preserving the existing center-tap speech and Home-to-Codex behavior.

**Architecture:** A new pure firmware `CharacterSelector` owns only the local character and transition time. Four independent vector drawing functions feed the existing Robot Home compositor; `main.cpp` maps Home up/down/right into selector operations and leaves audio, HID, workspace leases and Companion untouched.

**Tech Stack:** C++17, Arduino/M5Unified, M5GFX RGB565 sprites, PlatformIO native tests and USB-mic firmware build.

## Global Constraints

- Home starts and re-enters as Bumblebee.
- Up selects Optimus, down selects Megatron, right selects Starscream; repeating the selected target returns to Bumblebee.
- Up/down/right emit no HID, speech or haptic. Left and center tap preserve their current behavior.
- Center tap on every character uses the one existing task voice and microphone-priority rules.
- No Companion, Report ID 6, workspace lease, LaunchAgent or navigation mapping changes.
- No film frame, official logo, downloaded runtime asset or new distributable voice sample.
- Rendering remains non-blocking and uses the existing 20fps frame gate.

---

### Task 1: Local character selection state machine

**Files:**
- Create: `include/RobotHomeCharacter.h`
- Create: `simulator/robot_home_character_test.cpp`

**Interfaces:**
- Consumes: `touch_gesture::Direction` from `include/TouchGesture.h`.
- Produces: `robot_home::Character`, `robot_home::CharacterSelector::select(direction, nowMs)`, `reset()`, `character()`, `transitionProgress(nowMs)`.

- [ ] **Step 1: Write the failing selector test**

```cpp
#include <cassert>
#include "RobotHomeCharacter.h"

int main() {
  robot_home::CharacterSelector selector;
  using C = robot_home::Character;
  using D = touch_gesture::Direction;
  assert(selector.character() == C::Bumblebee);
  assert(selector.select(D::Up, 100) == C::Optimus);
  assert(selector.select(D::Up, 200) == C::Bumblebee);
  assert(selector.select(D::Down, 300) == C::Megatron);
  assert(selector.select(D::Right, 400) == C::Starscream);
  assert(selector.select(D::Right, 500) == C::Bumblebee);
  assert(selector.select(D::Left, 600) == C::Bumblebee);
  assert(selector.transitionProgress(500) == 0.0f);
  assert(selector.transitionProgress(820) == 1.0f);
  selector.select(D::Down, 1000);
  selector.reset();
  assert(selector.character() == C::Bumblebee);
}
```

- [ ] **Step 2: Run the test and capture RED**

Run:

```bash
clang++ -std=c++17 -Wall -Wextra -Werror -Iinclude \
  simulator/robot_home_character_test.cpp -o /private/tmp/robot-home-character-test
```

Expected: compilation fails because `RobotHomeCharacter.h` does not exist.

- [ ] **Step 3: Implement the minimal selector**

```cpp
namespace robot_home {
enum class Character : std::uint8_t { Bumblebee, Optimus, Megatron, Starscream };

class CharacterSelector {
 public:
  Character select(touch_gesture::Direction direction, std::uint32_t nowMs);
  void reset();
  Character character() const;
  float transitionProgress(std::uint32_t nowMs) const;
 private:
  static constexpr std::uint32_t kTransitionMs = 320;
  Character character_ = Character::Bumblebee;
  std::uint32_t transitionSince_ = 0;
};
}
```

Map only Up/Down/Right. Return Bumblebee when the mapped target is already selected. Clamp progress to `[0,1]` using unsigned subtraction so `millis()` rollover remains safe.

- [ ] **Step 4: Run GREEN and warning checks**

Run the Step 2 compile command, then `/private/tmp/robot-home-character-test` and `git diff --check`.

Expected: exit 0, no compiler warning and no whitespace error.

- [ ] **Step 5: Commit the selector**

```bash
git add include/RobotHomeCharacter.h simulator/robot_home_character_test.cpp
git commit -m "feat: add robot home character selector"
```

---

### Task 2: Independent cinematic vector renderers

**Files:**
- Create: `include/RobotHomeCharacters.h`
- Modify: `include/RobotHomeUi.h`
- Modify: `simulator/robot_home_ui_test.cpp`

**Interfaces:**
- Consumes: `robot_home::Character`, `robot_home::Mood`, `nowMs`, and transition progress.
- Produces: `robot_home::renderCharacter(surface, character, mood, nowMs, transitionProgress)` and the existing `robot_home::render(surface, State)` entry point.

- [ ] **Step 1: Extend the renderer test and capture RED**

Add `character` and `transitionProgress` to `robot_home::State`, render all four characters, and assert their geometry fingerprints differ:

```cpp
std::vector<std::vector<int>> fingerprints;
for (auto character : {robot_home::Character::Bumblebee,
                       robot_home::Character::Optimus,
                       robot_home::Character::Megatron,
                       robot_home::Character::Starscream}) {
  Surface surface;
  robot_home::State state;
  state.character = character;
  state.transitionProgress = 1.0f;
  robot_home::render(surface, state);
  fingerprints.push_back(surface.geometry);
}
for (std::size_t i = 0; i < fingerprints.size(); ++i)
  for (std::size_t j = i + 1; j < fingerprints.size(); ++j)
    assert(fingerprints[i] != fingerprints[j]);
```

For every character, repeat existing battery/charging/mood/power-overlay bounds checks and add transition progress values `0.0f`, `0.5f`, and `1.0f`.

Run:

```bash
clang++ -std=c++17 -Wall -Wextra -Werror -Iinclude \
  simulator/robot_home_ui_test.cpp -o /private/tmp/robot-home-ui-test
```

Expected: compilation fails because the new state fields and renderer do not exist.

- [ ] **Step 2: Extract shared drawing primitives**

Create `RobotHomeCharacters.h` with a shared transform that applies breathing,
speech bob and the 320ms reveal scale/outline pulse. Expose exactly:

```cpp
template<class Surface>
void renderCharacter(Surface& surface, Character character, Mood mood,
                     std::uint32_t nowMs, float transitionProgress);
```

Keep shared helpers limited to polygon filling, transformed points, eye pulse and
talking offset. Do not share helmet geometry between characters.

- [ ] **Step 3: Implement four renderer functions**

Implement these private helpers with all coordinates inside the existing head
region `x=88..378`, `y=96..324`:

```cpp
drawBumblebee(surface, transform, eyeColor, mouthOffset);
drawOptimus(surface, transform, eyeColor, faceplateOffset);
drawMegatron(surface, transform, eyeColor, jawOffset);
drawStarscream(surface, transform, eyeColor, chinOffset);
```

Use the approved identities: Bumblebee yellow rounded antennae; Optimus red/blue
tall antennae and grille; Megatron asymmetric gunmetal crown and heavy jaw;
Starscream swept jet fins and narrow silver face. Draw a character-colored
outline pulse only while `transitionProgress < 1.0f`.

- [ ] **Step 4: Compose the selected portrait with existing chrome**

Update `robot_home::State`:

```cpp
Character character = Character::Bumblebee;
float transitionProgress = 1.0f;
```

Replace the current Bumblebee-only geometry block with `renderCharacter(...)`.
Keep connection text, mood/status line, measured battery grouping and power
overlay behavior unchanged. During idle use a neutral status line; during speech
retain the existing talking visual without adding character names or trademarks.

- [ ] **Step 5: Run renderer GREEN**

Run `/private/tmp/robot-home-ui-test` after the Step 1 compile, then compile and
run `simulator/robot_home_interaction_test.cpp` with the same flags.

Expected: all character fingerprints are unique; every primitive is within the
circular canvas; battery centering and existing tap/talking assertions pass.

- [ ] **Step 6: Commit the renderer**

```bash
git add include/RobotHomeCharacters.h include/RobotHomeUi.h \
  simulator/robot_home_ui_test.cpp
git commit -m "feat: render four cinematic robot home characters"
```

---

### Task 3: Connect Home gestures without host side effects

**Files:**
- Modify: `src/main.cpp`
- Modify: `simulator/robot_home_interaction_test.cpp`
- Modify: `simulator/robot_home_swipe_test.rb`

**Interfaces:**
- Consumes: `CharacterSelector` from Task 1 and `State.character` / `State.transitionProgress` from Task 2.
- Produces: firmware behavior only; no new wire message or Companion API.

- [ ] **Step 1: Add failing gesture contract coverage**

Extend the production-source swipe harness to assert that the Home Up/Down/Right
branch calls `robotCharacters.select(direction, millis())`, redraws, and returns
without `requestRobotReaction`, `sendSwipePress`, or `startHaptic`. Keep the Home
Left assertions for one HID press/release and one haptic.

Add a transition assertion to the native interaction test:

```cpp
robot_home::CharacterSelector characters;
characters.select(touch_gesture::Direction::Down, 100);
assert(characters.character() == robot_home::Character::Megatron);
characters.reset();
assert(characters.character() == robot_home::Character::Bumblebee);
```

Run:

```bash
ruby simulator/robot_home_swipe_test.rb
```

Expected: FAIL because the production branch still requests the laugh sound.

- [ ] **Step 2: Wire selection into the Home swipe branch**

Declare one `robot_home::CharacterSelector robotCharacters;`. Replace the current
Home Up/Down/Right laugh request with:

```cpp
stopRobotReaction();
robotCharacters.select(direction, millis());
drawScreen();
```

Do not start haptics, do not call the audio request function, and do not send a
swipe press. Leave Home Left byte-for-byte behaviorally equivalent.

- [ ] **Step 3: Feed selection into drawing and reset on exit**

When building `robot_home::State`, assign:

```cpp
ui.character = robotCharacters.character();
ui.transitionProgress = robotCharacters.transitionProgress(ui.nowMs);
```

In `handleWorkspaceModeTransition`, call `robotCharacters.reset()` only when
`previous == Home && next != Home`. Center tap continues calling the existing
`requestRobotReaction(RobotTask)` for every selected character.

- [ ] **Step 4: Run gesture and audio regression GREEN**

Run:

```bash
ruby simulator/robot_home_swipe_test.rb
ruby simulator/robot_speech_reaction_test.rb
ruby simulator/robot_speech_request_test.rb
```

Expected: Home up/down/right are local-only; center task speech, microphone
priority, Home Left haptic and cancellation behavior remain unchanged.

- [ ] **Step 5: Commit integration**

```bash
git add src/main.cpp simulator/robot_home_interaction_test.cpp \
  simulator/robot_home_swipe_test.rb
git commit -m "feat: switch robot characters from home gestures"
```

---

### Task 4: Native previews, documentation and complete verification

**Files:**
- Modify: `simulator/preview_main.cpp`
- Modify: `README.md`
- Modify: `README.zh-CN.md`
- Modify: `docs/ROBOT_SPEECH.md`
- Create: `docs/superpowers/plans/2026-09-20-robot-home-characters-verification.md`

**Interfaces:**
- Consumes: completed character selector and renderers.
- Produces: inspectable 466x466 previews and public interaction documentation.

- [ ] **Step 1: Add preview scenarios**

Accept these exact scenarios:

```text
home-bumblebee
home-optimus
home-megatron
home-starscream
home-optimus-transition
home-megatron-transition
home-starscream-transition
home-talking
```

Map each scenario to `State.character`; transition scenes use `0.5f`. Keep the
existing battery, offline, charging and power-overlay preview scenarios.

- [ ] **Step 2: Build and export real-size previews**

Run:

```bash
pio run -e native-preview
mkdir -p /private/tmp/agentbezel-character-previews
.pio/build/native-preview/program /private/tmp/agentbezel-character-previews/bumblebee.ppm home-bumblebee
.pio/build/native-preview/program /private/tmp/agentbezel-character-previews/optimus.ppm home-optimus
.pio/build/native-preview/program /private/tmp/agentbezel-character-previews/megatron.ppm home-megatron
.pio/build/native-preview/program /private/tmp/agentbezel-character-previews/starscream.ppm home-starscream
```

Convert copies to PNG under `/private/tmp`, inspect at original resolution, and
obtain user approval before any upload to the device.

- [ ] **Step 3: Update public documentation**

Document the exact local controls in both READMEs: up Optimus, down Megatron,
right Starscream, repeated direction Bumblebee, left Codex, center existing local
task voice. State that character swipes are silent, local-only and reset to
Bumblebee after leaving Home. Update `ROBOT_SPEECH.md` to clarify that selection
does not add voice samples and every portrait uses the same local task clip.

- [ ] **Step 4: Run the full native suite**

Compile every `simulator/*_test.cpp` with `clang++ -std=c++17 -Wall -Wextra
-Werror -Iinclude` plus the cached ArduinoJson include only for tests that need
it, and run every produced binary. Run all four Robot Home Ruby harnesses.

Expected: all tests and harnesses exit 0; record exact counts in the verification
document without calling harnesses XCTest.

- [ ] **Step 5: Build both firmware boundaries**

Run:

```bash
pio run -d usb-mic
pio run -e m5stack-stopwatch
git diff --check
```

Expected: USB-mic and default wireless builds pass without new warnings. The
public build must still compile with `RobotSpeechData::kAvailable == false` and
without the ignored private `RobotSpeechLocal.h`.

- [ ] **Step 6: Review and commit documentation**

Review `536499b..HEAD` for circular geometry, non-blocking animation, local-only
swipes, audio ownership, Home reset, default-firmware isolation and public asset
boundaries. Record findings and exact verification results, then commit:

```bash
git add simulator/preview_main.cpp README.md README.zh-CN.md \
  docs/ROBOT_SPEECH.md \
  docs/superpowers/plans/2026-09-20-robot-home-characters-verification.md
git commit -m "docs: explain robot home character controls"
```

---

### Task 5: Install and physical acceptance after preview approval

**Files:**
- Modify only the verification record after user-observed acceptance.

**Interfaces:**
- Consumes: verified USB-mic firmware from Task 4.
- Produces: user-attributed hardware acceptance; no merge or push.

- [ ] **Step 1: Preserve a recoverable firmware backup**

Build the current installed baseline if needed, copy `firmware.bin` into a new
private directory created with `mktemp -d /private/tmp/agentbezel-characters-backup.XXXXXX`,
and record its SHA-256. Do not remove earlier backups.

- [ ] **Step 2: Re-enumerate the C152 download device**

Ask the user to enter download mode, enumerate current `/dev/cu.*` devices,
identify the single new C152 port, report that exact port, and obtain new explicit
confirmation. Never reuse a historical port authorization.

- [ ] **Step 3: Upload only the USB-mic firmware**

Run `pio run -d usb-mic -t upload --upload-port <confirmed-port>`. Do not replace
or re-sign Companion 0.1.4, and do not modify its permissions or LaunchAgent.

- [ ] **Step 4: Perform physical acceptance**

Have the user observe: boot/re-entry Bumblebee; up Optimus; down Megatron; right
Starscream; repeated target returns Bumblebee; cross-direction direct selection;
silent non-haptic character changes; center task speech and unified animation;
Home Left vibration and Codex switch; sleep/power; microphone recording priority;
and unchanged Codex/SUPER/HERMES navigation.

- [ ] **Step 5: Record only observed results**

Append pass/fail observations and firmware hash to the verification record. Mark
every unobserved physical behavior `unverified`. Commit the record separately;
do not merge or push unless the user explicitly requests it.
