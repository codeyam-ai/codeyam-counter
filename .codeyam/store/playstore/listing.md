# CodeYam Counter — Google Play listing copy

Re-cut from `../appstore/listing.md` to Play's fields and limits. The two do not
map one-to-one: Play has no subtitle, no promotional text, and **no keywords
field** (it indexes the title and descriptions instead), while its short
description is 80 chars against the App Store subtitle's 30. Counts are shown so
this can be edited without overrunning.

Package: `com.codeyam.counter` · Category: **Tools** · Free · No ads

---

## App name  *(≤30 chars)*
`CodeYam Counter`  · 15

## Short description  *(≤80 chars — shown in search results and above the fold)*
`Tap to count anything. Unlimited color-coded tallies, one giant number.`  · 71

## Full description  *(≤4000 chars)*

CodeYam Counter is the counter app that gets out of your way.

One giant number. One big tap target. Count reps, cups, laps, tasks, birds —
anything — without hunting for a tiny button.

WHY YOU'LL LIKE IT

• A number you can actually read. The count fills the screen, so a glance from
  across the room is enough.
• Tap to increment, and that's it. The whole lower half of the screen is your
  “+”. Subtract and reset live right beside it.
• Keep every tally in one place. Add as many counters as you like — each with
  its own name and color — and switch between them with a swipe or a tap on its
  colored dot.
• Undo a reset. Zeroed the wrong counter? One tap puts it back.

MAKE EACH COUNTER YOURS

• Twelve colors to tell your counters apart at a glance.
• Count by any step — by 1, by 5, by 10, whatever you're tracking.
• Allow negatives, or clamp at zero.
• Sound and haptics on every change — pick a tock, pop, or click, or keep it
  silent. Set it once for the whole app, or override it per counter.

BUILT FOR ONE HAND

• Left- or right-handed layout, app-wide or per counter, so the buttons land
  under your thumb.

SEE IT ADD UP

• Every counter keeps a history. Open the graph to watch your count climb over
  time, with a running event log of every + and – and when it happened.

PRIVATE BY DESIGN

• Everything lives on your device. No account, no sign-in, no tracking, no ads.
  The app requests a single permission — vibrate, for haptics — and has no
  internet permission at all.

Whether you're counting reps at the gym, cups of coffee, inventory on a shelf,
or bugs in a sprint, CodeYam Counter makes it a single satisfying tap.

## Release notes  *(“What's new” — first release)*
Meet CodeYam Counter: unlimited color-coded counters, a giant tap-to-count
number, per-counter step / sound / haptics / handedness, reset with undo, and a
graph + event history for every counter.

---

## Graphics inventory

| Asset | Spec | File |
|---|---|---|
| App icon | 512×512, 32-bit PNG | `icon/PlayIcon-512.png` |
| Feature graphic | 1024×500 PNG | `feature-graphic-1024x500.png` |
| Phone screenshots | 2–8, 1080×2400 | `screenshots/phone/01…05-*.png` |

All three are produced by `../appstore/gen_assets.py` — the same generator that
emits the iOS icon — so the two stores' artwork cannot drift. Screenshots are
the real Android scenario captures, copied verbatim (already exactly Play's
phone spec) and deliberately **uncaptioned**: Play renders listing screenshots
small, so unmatted real captures read better than marketing frames. The choice
is applied consistently to all five.

Screenshot narrative, mirroring the App Store's:

1. `01-count-anything` — one giant, gorgeous number
2. `02-every-tally-one-tap-away` — push-ups · coffee · steps · bugs
3. `03-watch-it-add-up` — every count as a graph + event log
4. `04-make-it-yours` — color · count-by · sound · haptics
5. `05-one-handed-by-design` — left or right, your call

## URLs
- Privacy Policy URL: https://codeyam.com/counter/privacy  *(live)*
  Entered in **two** Play Console places: the Store listing privacy field and
  the Data safety form. Same policy the App Store listing uses.
- Support / contact: https://codeyam.com/support  *(placeholder — confirm)*

## App content declarations
Every answer Play requires is pre-written in `PLAY_CONSOLE_CHEATSHEET.md` —
Data safety (nothing collected, nothing shared), content rating (Everyone),
target audience (13+), ads (none), app access (no gating).
