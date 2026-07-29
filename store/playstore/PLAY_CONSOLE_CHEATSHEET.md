# CodeYam Counter — Play Console "App content" cheat-sheet

Answers for the Play Console **App content / Policy** declarations you must clear
before rolling out (even to Internal testing). Package: `com.codeyam.counter`.
All answers reflect what the app actually does: everything is stored on-device
(Android `SharedPreferences`), no network calls, no accounts, no ads, no SDKs
beyond AndroidX/Compose.

---

## Privacy policy
- **URL:** `https://codeyam.com/counter/privacy`  *(live)*
- Note: the page is OS-neutral ("mobile application", "on-device storage") but
  mentions iCloud backups; fine for internal testing. For production you may want
  to make the backup line OS-neutral (Android uses Google/Auto Backup).

## App access
- **All functionality is available without special access.**
  (No login, no accounts, nothing gated — reviewers can use everything as-is.)

## Ads
- **No, my app does not contain ads.**

## Content ratings (IARC questionnaire)
- **Category:** Utility / Productivity / Tools (choose "Utility, productivity,
  communication, or other").
- Answer **No** to every content question: violence, sexuality, nudity,
  profanity, controlled substances, gambling, fear/horror, user interaction,
  shares location, digital purchases.
- **Expected result: Everyone / PEGI 3 / rated for all ages.**

## Target audience and content
- **Target age group:** **13 and older** (recommended — keeps you out of the
  "Designed for Families" program's extra requirements).
- **Is the app directed at children?** **No** — it's a general-purpose utility.
  (You *can* include younger ages later, but that adds Families-policy compliance.)

## Data safety  *(the important one)*
- **Does your app collect or share any of the required user data types? → No.**
- Data collected: **None.** Data shared: **None.**
- Rationale: all counters, histories, colors, and settings persist only in local
  `SharedPreferences`; the app makes no network requests, has no accounts, and
  bundles no analytics/crash/ads SDKs (only AndroidX + Jetpack Compose).
- Encryption in transit / data deletion: **N/A** (nothing is collected or sent).

## Government apps
- **No**, this is not a government app.

## Financial features
- **None** — no financial features.

## Health
- **No** health content or features.

## Other declarations
- **News app:** No.
- **COVID-19 contact tracing / status:** No.

## Store settings
- **App category:** **Tools** (Productivity is a fine alternative).
- **Store listing** (not required for internal testing; needed for production):
  title `CodeYam Counter`, short description (≤80), full description, phone
  screenshots (1080×2400), **feature graphic 1024×500**, 512×512 icon.

---

### Reminder — for *production* (not internal testing) you'll also need:
full store listing + feature graphic + 512×512 icon, and (for a brand-new
personal developer account) Google's **closed-testing-before-production**
requirement (≥12–20 testers for 14 days). Internal testing has none of that.
