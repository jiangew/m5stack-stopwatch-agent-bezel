# Centered notification body update — 2026-10-20

Status: flashed and independently verified; physical acceptance pending.

- Installed source: `ae5a8a5386942520796c1701b54004764580eb4b`.
- Environment: isolated USB-mic `m5stack-stopwatch-home-imu`.
- Image size: 2,667,632 bytes.
- SHA-256: `e52dc2ae1f7787a455d3561503d325bd7490bc882ef0631bba8d89b05a789cb8`.
- Previous verified source: `5ce58d15c9ed8ccd6af175eedaff111421af1eaa`.

The user requested centered body text again because most notifications are
short. All notification body lines now use middle-center alignment at x=233.
Current font sizes, row limits, full 192-byte context, Home-only badge geometry
and gesture behavior are retained. Existing UI regressions and native short,
maximum-length browsing and read-only Detail previews passed. The selected
USB-mic + Home IMU firmware build passed before updating.

The user ran the prepared Terminal updater and reported UPDATE VERIFIED.
Independent checks confirm byte-identical application readback, unchanged
protected first 64 KiB, complete 6,553,600-byte prior app0 backup with matching
full/prefix hashes, and an installed receipt matching this image. Only app0 at
0x10000 was updated after interactive exact-port confirmation. Earlier images
and private backups are retained; no Companion binary or GATT schema changed.

Physical centered layout, font comfort and notification/Home/Agent controls
remain pending user confirmation after a short reset. No fresh audio capture
or host HID enumeration claim is made from a successful firmware write alone.
