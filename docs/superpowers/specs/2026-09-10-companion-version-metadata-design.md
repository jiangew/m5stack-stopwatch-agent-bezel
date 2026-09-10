# Companion version and installation metadata

Status: Design agreed in conversation; written specification awaiting review.

## Goal

Make an installed Companion distinguishable from an older build without relying
on the unchanged application name. Apply this with the next permission-fix
installation, not during the current permission investigation.

## Agreed behavior

- The next release uses `CFBundleShortVersionString` = `0.1.1`, replacing `0.1.0`.
- `CFBundleVersion` is a monotonically increasing numeric build number. The next
  packaged build uses `2`; later newly packaged builds increment it. Reinstalling
  the same artifact retains its build number.
- Packaging records the full source Git commit and UTC build timestamp in custom
  Info.plist metadata, `AgentBezelSourceCommit` and `AgentBezelBuildTimestamp`.
  These identify the actual build input, not the date of an unrelated later
  documentation commit. Release packaging requires a clean source checkout.
- Write metadata before signing. Preserve the bundle identifier, executable name,
  existing permission descriptions and background-app behavior.
- After successful installation and signature verification, update only the
  outer `.app` directory modification time to the actual installation time.
  Preserve its creation time. Build time and installation time are distinct.
- Finder exposes the release version and modification time. Detailed build
  number, commit and build timestamp remain available in Info.plist; do not
  promise that Finder displays these custom fields.

## Boundaries and rollout

No changes to the currently installed app, signature, permissions, LaunchAgent,
firmware, protocols or shortcut mappings are authorized by this documentation
step. Do not present metadata changes as a fix for the permission problem.

Implement packaging metadata with the next approved repair installation. Back up
the installed app first, preserve its signing identifier, and verify the resulting
signature. Permissions may need reauthorization after that future installation.
No merge or push is included.

## Acceptance

- Check packaged and installed metadata against version `0.1.1`, build `2`, the
  exact source commit and a valid UTC timestamp.
- Check installed executable identity against the signed release artifact.
- Verify signature validity after updating the outer directory timestamp.
- Confirm creation time is preserved and modification time reflects installation.
- Have the user verify the new version and modification time in Finder.
- Keep permission/navigation acceptance separate from metadata acceptance.
