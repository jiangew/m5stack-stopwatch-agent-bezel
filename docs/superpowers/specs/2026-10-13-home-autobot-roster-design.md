# Home Autobot roster — approved design

The user approved the full-body anime previews of Optimus Prime, Jazz and Hot Rod, requested a retained default Bumblebee portrait plus six full-body Autobots, and selected Wheeljack and Hound as the two additional members.

## Characters and navigation

- The seven distinct renderable characters are Bumblebee (existing portrait), Bumblebee Fullbody, Optimus Prime, Jazz, Hot Rod, Wheeljack and Hound.
- Boot and the next Home visit after leaving it show the unchanged Bumblebee portrait. Existing reconnect/workspace selection policy stays intact.
- Up/down/right from the default portrait uniformly select one of the six full-body characters. Subsequent up/down/right uniformly select one of the other five full-body characters. The portrait never appears in the swipe pool; consecutive repetition is forbidden.
- Left retains workspace cycling. Sleeping first touch only wakes. Held swipes do not repeat. Existing immediate press, interruptible 420ms skill, haptics and power behavior remain.

## Artwork and rendering

The approved three full-body source PNGs are reused. Three new images use the same clean outlined, cel-shaded anime mecha treatment: yellow Bumblebee, white/green Wheeljack with illuminated ear panels, olive-green Hound with rugged vehicle armor. All bodies are visible, with black safety margins and recognizable head/chest shapes at the actual display size. Bumblebee portrait JPEG bytes stay unchanged.

Seven 300x300 baseline JPEGs are embedded, each below 50KiB. Full RGB565 cache allocation is 1,260,000 bytes in PSRAM; partial allocation falls back to the existing one-buffer path without repeated per-frame decode/allocation. All seven images must be reachable in the full cache and fallback. Native preview uses the same cache, transforms and clip path. Character accents replace the retired Iron Man/Spider-Man effects with Autobot-appropriate accents (yellow sparks, cyan scan, blue sound rings, orange speed streaks, green engineering sparks and green radar).

## Verification and deployment boundary

Test initial six-way selection, all six current bodies and five alternatives, entropy rejection for each range, portrait exclusion, no immediate repetition, ignored directions, reset/wraparound, real firmware gesture behavior and cache pressure/failure recovery. Decode and reproduce all seven assets and inspect actual native idle/press/skill/end frames for protected status/battery pixels. Build native preview, default firmware and the previously chosen five-screen USB-mic firmware.

The user reported the earlier deployed interactions normal. This change is not physically accepted until tested on C152. Do not upload automatically: resolve/report the current exact download-mode port and obtain fresh flash approval under AGENTS.md. No Companion changes, credentials, private identifiers, recorded audio, push or merge are in scope.
