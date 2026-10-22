# Notification content V2: installation and physical acceptance

Date:2026-10-22. Implementation source:`7ec093f64390b147aa285c0be36bc2cae4b4d212`.
This records one user-confirmed C152 installation, separately from the
[candidate source/build evidence](NOTIFICATION_CONTENT_V2_20261022.md).

## Observed update

- Identified the exact connected device and user-confirmed USB port. Verified the
  known C152 identity, ESP32-S3 and16MB Flash. Actual app0 is0x10000, size0x640000.
- Backed up full app0 and protected first64KiB. The previous application matched
  the accepted source `33de6d4` and SHA-256
  `d170eb3df75c9c1f9105eaf2218d93f9ae12d70763ad3eb9cd17bd4b33294821`.
- Wrote only the selected USB-mic+IMU application,3582896 bytes, SHA-256
  `64068d34d470280e22031a3997fc21402c5c8a31bfa078f1455afe1d620d8e24`.
  Write hash, independent application readback and protected-area comparison
  passed. Bootloader, partition table, NVS and OTA metadata stayed unchanged.
- Installed signed Companion build16 at the existing application location,
  retaining the prior application and configuration backups. Enabled the explicit
  Companion V2 flag and Codex rich-content flag. Updated OPEN relay to accept the
  compatible optional fields; preserved the outer Codex/Computer Use callback and
  other harness collectors. Both LaunchAgents were observed running.

## Physical and runtime acceptance

The user lightly reset the device and re-added the current App in Input
Monitoring and Accessibility. After Companion restart, logs reported authorized
Accessibility and a connected HID. Quota writes resumed; no ingestion/storage
error was observed for the synthetic acceptance events.

The user confirmed both Chinese UI acceptance notices displayed normally:
Chinese task name, project/time, selected n/N, TURN ENDED and MORE ON MAC.
Up/down switched title and index; TAP, LEFT/RIGHT, BACK and original Home/Agent
controls were reported normal. The two notices were explicitly synthetic.

USB microphone enumeration and HID/IMU RPC passed. A2-second input-only capture
contained96256 frames, mono48kHz16-bit PCM, duration2.005333333 seconds. Only
statistics were retained; the temporary WAV was deleted. This validates capture
continuity/format, not acoustic quality, latency or noise measurements.

## Native content boundary

The installed Codex adapter successfully performed an exact current-thread
metadata-only read: verified root lineage, native name and working-directory
availability, without turn history or logged content values. A sandboxed probe
was denied; the normal host-context probe passed. The installed hook runs in
that normal host context.

At the physical acceptance checkpoint, a genuine automatic callback was still
pending. During merge preparation, one natural current-thread Codex turn-complete
callback was observed and persisted by the installed real broker. Its native
name, project and reply excerpt were present and its state was resolved. Exact
identity and content values were not logged or tracked; no extra inference task
was started. This proves automatic ingestion, while physical viewing of this
particular real notice was not separately reported.

Existing generic queue records do not retroactively gain task names or result
excerpts; new opted-in callback events carry the richer content. Other harness
content collection remains unchanged.

Device binding, native IDs, actual task names, audio and private installation
paths are omitted here. Private firmware/App/config backups and receipts remain
available for rollback. Disable the two rich-content flags before using an older
Companion or firmware. No merge or remote push was performed for this update.
