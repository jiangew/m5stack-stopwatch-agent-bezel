# Single-layer notification reading

User chose to remove the redundant read-only Detail layer after physically
accepting the reply-model release. Reuse the existing isolated feature worktree.

All stock canDecide=false notices use Inbox/Toast as their only reading page.
Body taps stay on that page and do not emit OPEN or a second READ. A clearly
labelled OPEN ON MAC button invokes the existing identity-bound OPEN action.
UP/DOWN browse, LEFT dismisses, RIGHT/BACK return Home. A tap on a transient
Toast pins it as Inbox, without introducing another layer or hiding after5s.
Native decision-capable cards retain their complete scope, detail/hold gate and
confirmation protocol. They are not enabled by this change.

Body text stays centered. Rich English uses native Space Mono22 instead of24;
Chinese uses the existing24px CJK glyphs at22/24 scale for approximately22px.
Rich body baseline spacing increases26→28px. Limit rich excerpt to five rows so
text does not collide with MORE ON MAC or the compact footer. Titles, model/time,
status, badge and Home/Agent layouts are unchanged. Preserve all192 ASCII scope
bytes on legacy cards; seven28-column rows at22px with23px baseline spacing fit
above the footer for read-only legacy cards.

Footer: MORE ON MAC remains a truncation indicator. OPEN ON MAC is a separate
140×32px button at(256,360). UP/DOWN hint at(88,376); LEFT and RIGHT hints at
(88,402)/(256,402), left-aligned. BACK stays at(233,430). The button hit rectangle
matches its rendered bounds. Gesture classification precedes button activation;
a swipe starting on the button cannot emit OPEN. Stale/disconnected/busy action
protections remain unchanged.

Regression gates: real controller tests for taps/pinned Toast/button/swipes/ACK,
renderer tests for button/scope/body-footer separation, existing parser/controller/
UI/main-loop/legacy suite under ASan/UBSan, native framebuffer comparison for
Chinese/English/long/waiting notices. Preview only; do not flash without later
user authorization and the project exact-port gate.
