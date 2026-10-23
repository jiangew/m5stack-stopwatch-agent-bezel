# Notification footer buttons

User approved replacement of the previous footer. Keep single-layer reading,
centered22px body/28px baselines and model/title/status. Remove MORE ON MAC and
bottom standalone BACK. The read-only footer has BACK left and OPEN right,
140×48px at(78,344)/(248,344),30px gap,12px rounded corners, native22px labels.
BACK fill#202A36/text#DCE5EF; OPEN fill#16465A/text#83E5FF. Native14px hints:
UP/DOWN: BROWSE centered at(233,408); LEFT: DISMISS at(125,426) and RIGHT: BACK
at(253,426), both left-aligned. At most five body rows end before the buttons;
overflow keeps ellipsis. Legacy read-only excerpts use that same bounded body
layout; native decision-capable complete scope and hold controls remain intact.

Share rendered button rectangles with hit testing;8px outward padding leaves
separate regions. Capture the target on press, permit release drift strictly
less than20px, cancel a click after movement>=20px, classify existing>=52px
swipes first. No bottom-wide BACK zone on read-only pages. Body/hint/gap taps
cannot open or close; Toast body taps still pin via first READ. OPEN stays on
page, BACK and right swipe return Home; existing action freshness/busy guards
remain. No protocol/Companion/collector change. Codex opens exact task; DSH
requests app activation only.

Validate actual controller actions, hint/button geometry and native fonts;
ASan/UBSan parser/controller/UI/main-loop/legacy regressions; native framebuffer
Chinese/English/long/waiting previews; default and selected USB-mic+Home-IMU
builds. Update only app0 after fresh exact-port confirmation, identity and full
app/protected backups, baseline comparison and readback/protected checks. User
physical acceptance is separate. Preserve recovery/rollback artifacts.
