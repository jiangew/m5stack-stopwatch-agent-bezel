# Home tap motion pilot — throwaway

Question: do distinct body gestures make the central tap read as a character
responding, while keeping the accepted artwork and Home layout?

This branch captures the first two pilots from the approved design: Bumblebee
full body waves; Optimus Prime raises a fist and nods. Two real image-generation
pose edits per character are registered to the original idle transform. The
four baseline JPEGs are captured here; source hashes and crop registration are
in `manifest.json`. Accepted idle assets are read from the existing repository.

The native pilot calls the real Home renderer, font, JPEG decoder, RGB565 sprite
operations and portrait clip rectangle. It replaces only portrait drawing;
the old energy effects are absent. The timeline is 400ms idle, 100ms press at
97% scale, 600ms gesture including return, and 700ms idle. Each loop contains
54 frames at 30fps. Small upward motion accompanies the body pose changes.
The pilot does not implement eye illumination, haptics, or firmware timing.

Run using Python with Pillow and numpy, after the existing native preview has
been built:

```sh
python3 simulator/prototypes/home_tap_motion/run.py
```

`--output-dir` selects a local output directory. The command builds a native
renderer and emits a looping GIF, a keyframe contact sheet, native frame files,
`validation.json`, and a standalone `index.html`. Open the HTML directly, or
serve that directory using `python3 -m http.server --bind 127.0.0.1`.

The HTML plays captured native pixels. Its pointer handlers demonstrate instant
press feedback, release under 500ms, a 600ms response, immediate interruption on
another press, and cancellation after leaving the center or moving 52px. The
browser is a visual pilot, not evidence of the device's gesture detector,
touch latency, memory headroom, long power hold, or motor behavior. It has no
firmware connection or device writes. The eight-character random pool remains
in the existing production implementation.

2026-10-14 evidence: native build and 108-frame render succeeded; status and
battery pixels stayed unchanged in all frames; both final idle frames matched
their initial idle pixels exactly. Initial idle also matched the current native
Home renderer for each character. Browser checks observed a double tap producing
two responses with immediate restart, Optimus responding once, drag cancellation
without another response, and a 650ms hold without a short-tap response.

Verdict: the two motions are visible at actual Home size and preserve the
accepted layout. The gesture sequence uses discrete key poses; user acceptance
of the motion style and rhythm is pending before expanding the artwork to the
remaining characters. No new firmware build or flash is claimed.
