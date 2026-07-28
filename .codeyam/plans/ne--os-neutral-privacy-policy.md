---
title: "ne -- Make the privacy policy OS-neutral for the Play listing"
prefix: "ne"
mode: backend
createdAt: "2026-07-28T23:45:00Z"
source: manual
---

## Summary

The live privacy policy at `https://codeyam.com/counter/privacy` was written for
the iOS app and contains **one sentence that is factually wrong for Android
users**. CodeYam Counter is now submitted to Google Play (versionCode 110003,
awaiting first-app review), and Play reviewers check that the linked policy
describes *this* app on *this* platform. An iOS-only storage claim on an Android
listing is a legitimate rejection trigger, not a cosmetic nit.

This is a content fix to a hosted web page, not an app change. **No new build,
no resubmission of the AAB.** The policy URL is a live link, so editing the page
takes effect immediately — including while the app is still under review, which
is why this is worth doing now rather than after a rejection.

The rest of the policy is already platform-neutral and accurate, so the change
is deliberately narrow.

## The defect

Everything else in the policy holds up on Android. It already says storage is
handled "using the operating system's standard on-device storage" — correctly
neutral. The single problem is the backup sentence:

> It is included in your device's own backups if you have those enabled (for
> example, iCloud or encrypted local backups), and those backups are governed by
> **Apple's** privacy policy, not ours.

Two errors for an Android reader:

1. **iCloud** does not exist on Android. Android uses Google's backup service
   (Auto Backup / Backup by Google One).
2. **"governed by Apple's privacy policy"** points an Android user at the wrong
   company's policy entirely — the one claim in the document that is actively
   misleading rather than merely incomplete.

## Verified facts about the app (do not re-derive)

Confirmed against the shipped Android manifest and source, so the policy's other
claims are safe to leave alone:

- **`VIBRATE` is the only permission requested.** There is no `INTERNET`
  permission, so "no network requests" is not just true, it is enforced by the
  manifest.
- Counters, histories and settings persist to local `SharedPreferences`
  (Android) / `UserDefaults` (iOS). No accounts, no analytics, no ads, no
  third-party SDKs beyond AndroidX/Compose.
- Uninstalling removes the data — the policy's deletion claim is correct.
- The page already names the app, carries a Last Updated date (July 10, 2026)
  and a contact (`privacy@codeyam.com`), and loads publicly without a login —
  all four are Play requirements and all four already pass.

## Key decisions

- **Fix the one sentence; do not rewrite the policy.** It is accurate, short,
  and already reviewed. A rewrite risks introducing a claim that contradicts the
  Data safety form, which Play cross-checks against the APK.
- **One policy for both platforms, not two.** The app has identical
  zero-collection behaviour on iOS and Android. Two documents would drift, and
  the same URL is already recorded in both store listings
  (`store/appstore/listing.md`, `store/playstore/listing.md`).
- **Name both vendors rather than going vague.** "your device's backup service"
  is neutral but tells the reader nothing about whose policy governs their data.
  Naming Apple *and* Google keeps the useful information while being correct on
  both platforms.
- **Bump the Last Updated date.** A policy edited without a date change looks
  stale to a reviewer comparing it against a recently-submitted app.

## Implementation

### 1. Find where the page is authored

**This is the one genuine unknown.** The page is NOT in `codeyam-counter`, and a
grep of `~/codeyam` did not find it either. Before editing anything, locate the
source — candidate homes among the sibling checkouts include `~/codeyam`,
`~/fun-site`, `~/nadia-website`, or a separate site repo / CMS not cloned
locally.

Search for a distinctive string from the live page rather than a filename:

```bash
grep -rl "iCloud or encrypted local backups" ~ --include="*.html" \
  --include="*.md" --include="*.mdx" --include="*.tsx" --include="*.astro" 2>/dev/null
```

If nothing turns up, the page is edited outside version control (hosted CMS,
Webflow, Framer, etc.) and steps 2–3 are done in that tool instead.

### 2. Replace the backup sentence

Change:

> …(for example, iCloud or encrypted local backups), and those backups are
> governed by Apple's privacy policy, not ours.

To:

> It is included in your device's own backups if you have those enabled — for
> example iCloud or an encrypted local backup on iOS, or Google's backup service
> on Android. Those backups are handled by Apple or Google respectively and are
> governed by their privacy policies, not ours.

Keep the surrounding sentences untouched.

### 3. Bump the Last Updated date

Set it to the edit date. Nothing else in the document changes.

### 4. Verify

```bash
curl -s -o /dev/null -w "%{http_code}\n" -L https://codeyam.com/counter/privacy
```

Must be `200` and must render without a login (Play rejects a policy behind
auth). Then re-read the live page and confirm the word "Apple" no longer appears
without "Google" alongside it.

## Optional, same edit if cheap

- The policy says nothing about the **`VIBRATE` permission**. Not required —
  Play's Data safety form covers *data*, and vibration collects none — but one
  clause ("the app requests permission to vibrate your device, purely for haptic
  feedback; this collects no information") pre-empts a reviewer wondering why a
  no-data app requests a permission at all.
- Consider adding "Android" alongside "iOS" wherever platforms are named, so the
  document visibly covers both.

## Out of scope

- No app code, no rebuild, no new versionCode, no AAB resubmission.
- No change to the Data safety answers in
  `store/playstore/PLAY_CONSOLE_CHEATSHEET.md` — they are already correct
  (nothing collected, nothing shared) and this edit does not alter what the app
  does.

## Scenarios to demonstrate

None. This is an external web page with no app surface, so there is nothing for
a codeyam scenario to render. Verification is the `curl` check plus a read of
the live page.
