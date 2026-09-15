# Home left-swipe haptic follow-up

User confirmed all four screens' interactions now work with Companion 0.1.4;
the remaining inconsistency is Home left-swipe vibration. Other unreported
acceptance layers, including new-version audio and long-term stability, remain
unverified.

## Change

Only awake, host-ready Home left sends the existing swipe haptic with the same
strength/duration as the other pages. The existing active-swipe latch prevents
repeated pulses within one gesture. Offline left and local facial interactions
remain silent. No change to wake behavior, Companion, protocol or LaunchAgent.

## Verification and installation

The new native harness compiles the actual updateTouchGesture function with
hardware-boundary doubles: initially failed for a missing haptic, then passed
after the minimal fix. Cases cover pulse parameters, duplicate movement, offline
left, three local directions, subthreshold movement and consumed wake behavior.
Run it using `ruby simulator/robot_home_swipe_test.rb` alongside the native suite.

Prior installed Home firmware is retained as a private recovery artifact.
Fresh download-port enumeration and exact-port consent are required before
upload. Device haptic consistency is **unverified** until user observation.
Do not reinstall Companion, merge or push.
