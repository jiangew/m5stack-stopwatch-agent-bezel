# Notification footer layout update

## Approved layout

- Four hints form two independently left-aligned columns: UP/DOWN above LEFT,
  TAP above RIGHT. Column anchors are x=88 and x=264.
- Use the existing native 15px Space Mono font, reduced from 18px.
- Move the hint rows up 10px, to y=378 and y=395. BACK stays at y=430.
- Browsing body leading changes from 24px to 23px so all eight rows remain
  separate from the raised hints. Body font, centering and 192-byte capacity
  remain intact; read-only detail and decision layouts retain their leading.
- Touch regions, actions, Home, workspace controls, audio and haptics are unchanged.

## Validation

- Native preview built and short/192-byte notification frames inspected.
- Pixel checks measured a minimum 12.5px footer-to-ring margin. Long body ink
  ended at y=369 and hint ink started at y=373, without overlap.
- Updated renderer regression passed with ASan/UBSan: four native-font labels,
  independent column alignment, unchanged BACK, full context and offline rules.
- Notification firmware/main-loop regression passed for default and USB-mic paths.
- Standard firmware and USB-mic + Home IMU builds passed.
- Application image: 2710144 bytes, SHA256
  d170eb3df75c9c1f9105eaf2218d93f9ae12d70763ad3eb9cd17bd4b33294821.
- git diff --check passed. Prior accepted firmware and receipts are preserved.

## Device gate

Private app0/protected-area backup is in progress. Exact live-port confirmation,
app0-only write, independent readback, protected-region comparison and physical
UI acceptance remain required before calling this device update accepted.
