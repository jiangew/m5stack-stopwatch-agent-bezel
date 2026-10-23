# Reply-model notification update: deployment evidence

Date:2026-10-23. Implementation source:`ded3a065a7a86d488812e3a3a0f232c7cd0b88a0`.
See [candidate semantics and build evidence](NOTIFICATION_REPLY_MODEL_20261023.md).

## Firmware and Mac installation

The user confirmed the exact connected C152 download port before writing.
Device identity, ESP32-S3 and16MB Flash were checked. Full app0 and protected
first64KiB backups were verified; the previous application matched accepted
source`7ec093f` and SHA-256
`64068d34d470280e22031a3997fc21402c5c8a31bfa078f1455afe1d620d8e24`.

Only app0 at0x10000 was written with the selected USB-mic+Home-IMU image:
3583904 bytes, SHA-256
`1da50ef0bfdce161d6de335a988a725e969ad52558910c6b61af6a27ea80f55d`.
Write hash and independent readback passed. Protected first64KiB stayed identical;
bootloader, partition table, NVS and OTA metadata were preserved.

Companion build18 and the14 hash-verified collector/relay release files were
installed. Codex retained its outer callback and rich-content flag. The DSH
notification plugin and its relay path were updated with rich content enabled;
other profile nodes were preserved by semantic comparison. DSH hot reload was
observed through the new release relay process. Companion and generic OPEN relay
LaunchAgents were observed running. Native approvals remain disabled, with
confirmation handled on the Mac. Existing device binding and other harness paths
were preserved. Prior App/configuration and device backups remain available.

## Post-update runtime checks

The user reported a light RESET and re-added the installed App in Accessibility
and Input Monitoring. After Companion restart, logs reported authorized
Accessibility and connected StopWatch HID, without the prior Input Monitoring
denial. Normal USB microphone enumeration and both HID device-status and IMU
RPC passed.

A temporary input-only USB capture passed:96768 frames, mono48kHz16-bit PCM,
2.016 seconds. The WAV was deleted; only diagnostic statistics were retained.
This establishes enumeration/capture format and continuity, not acoustic quality
or measured latency.

## Physical acceptance checkpoint

Two explicitly synthetic Codex/DSH notices, with different model versions and
Chinese titles, were sent through the installed adapter bridge. The user confirmed
the model/time display matched expectations, without the configuration prefix,
and that CONNECTED, notification browsing/TAP/LEFT/RIGHT/BACK, Home tilt and Agent
controls were normal. The user separately requested a smaller body font, increased
line spacing and a way to return from Detail to the preceding notification view;
these are follow-up changes, not part of this installed image. Synthetic delivery
does not establish a fresh native DSH task callback or actual execution-model telemetry.
The source/native Session contract fixtures and installed observer reload are
separate evidence. Last-reply extraction still requires explicit model metadata
or an unambiguous annotation; otherwise exact-session configuration is used.

Device identifiers, actual task text, user paths and recordings are omitted.
No main-branch merge or remote push was performed for this deployment.
