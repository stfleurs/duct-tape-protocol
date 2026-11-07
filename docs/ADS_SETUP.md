# AdMob setup and store checklist

This document is the operational checklist for the ads in Duct Tape Protocol v0.5. The code is
already wired; the items below are the AdMob, Android build and Play Console steps that cannot be
done from inside the repository.

## Current configuration

| Item | Value |
|---|---|
| AdMob app ID | `ca-app-pub-7279753852255468~6806201948` |
| Rewarded — `DTP_Rewarded` | `ca-app-pub-7279753852255468/8204090272` |
| Interstitial — `DTP_Interstitial` | `ca-app-pub-7279753852255468/6891008607` |
| Banner — `DTP_Banner` | `ca-app-pub-7279753852255468/9599886240` (code present, disabled) |
| Plugin | Poing Studios Godot AdMob v5.0.0, vendored in `addons/admob/` |
| Android SDK | min 24, target/compile 35, arm64-v8a only, Gradle build on |

Where the settings live:

- `project.godot` → `[admob] general/android/app_id`, and the enabled editor plugin.
- `scripts/ad_manager.gd` → unit IDs, consent, ad cadence, test-ad switch, banner switch.
- `export_presets.cfg` → Gradle build, SDK levels, internet/network-state permissions, version.

## 1. AdMob console

1. Sign in at <https://admob.google.com/> with the account that owns publisher
   `pub-7279753852255468`.
2. Confirm the app **Duct Tape Protocol** exists with the Android package
   `com.boyoapps.ducttapeprotocol` and the app ID above. If the app is still "Not linked", link it
   to the Play listing once the first build is on a testing track.
3. Confirm the three ad units above exist and are **Active**. Use the exact unit IDs; a typo is
   silent (the ad simply fails to load) and is logged as `AdManager: ... failed to load`.
4. Complete **Payments** (name, address, tax information, payment method) and the **identity
   verification** flow. Ads serve before verification, but earnings are held.
5. In **App settings**, set an appropriate **maximum ad content rating** (for this game, `G` or
   `PG`) and review the blocked categories. Do not allow mature categories in a colourful
   all-ages-looking game.
6. Add the **app-ads.txt** entry (see section 5). Without it, demand and revenue are reduced.

## 2. GDPR / UMP consent message

The code calls UMP on every launch before any ad request. The message itself must be created in
AdMob:

1. Open **Privacy & messaging** in AdMob.
2. Create a **GDPR message** for the Android app.
3. Select the EEA, UK and Switzerland. Add the hosted privacy policy URL
   (`https://boyoapps-pages.pages.dev/duct-tape-protocol/privacy/`).
4. Keep the standard Google consent options (consent, do not consent, manage options) and review
   the **ad technology providers** list. If you remove providers, verify that the ads you receive
   are still allowed.
5. Publish the message. An unpublished message is not shown, so `PRIVACY OPTIONS` will also not
   appear.
6. Optionally create a **US states** message if you want the CCPA/CPRA opt-out entry point. The game
   already shows **SETTINGS → PRIVACY OPTIONS** whenever UMP reports that an entry point is
   required, so no code change is needed.

Test the consent form before release:

- In `scripts/ad_manager.gd`, set `DEBUG_EEA_CONSENT = true` in a debug build. The next launch
  requests the form as if the device were in the EEA.
- Add your device's hashed ID to `CONSENT_TEST_DEVICE_IDS` if you need a specific test device.
  The hashed ID is printed by the UMP SDK in logcat.
- To see the form again, clear the app's storage (Android **Settings → Apps → Duct Tape Protocol →
  Storage → Clear storage**) or temporarily call
  `UserMessagingPlatform.consent_information.reset()` from a debug build.
- Set `DEBUG_EEA_CONSENT` back to `false` before the release build.

If consent cannot be obtained, `ad_manager.gd` leaves ads off for that session rather than serving
without a lawful basis.

## 3. Code switches

| Constant / method | Default | Meaning |
|---|---|---|
| `USE_TEST_ADS_IN_DEBUG` | `true` | Debug builds request Google's sample units, not the live units. |
| `ENABLE_BANNER` | `false` | Banner code and unit ID stay ready, but no banner is shown. Flip only after checking the menu layout. |
| `INTERSTITIAL_EVERY_N_SHIFTS` | `3` | First interstitial after 3 finished shifts, then at most once per 3. |
| `INTERSTITIAL_MIN_GAP_SEC` | `180` | Hard minimum between interstitials, even across relaunches. |
| `ALLOW_DEV_SIMULATION` | `true` | Editor/desktop/Web get a 1.2 s fake ad for UI work and tests. Android/iOS never simulate. |
| `DEBUG_EEA_CONSENT` | `false` | Force the EEA consent flow in debug builds. |

Interstitials are only requested from the results screen's **NEXT**/**RETRY** handlers
(`scenes/results/shift_results.gd`), never from gameplay, and are skipped after a rewarded ad in
the same results screen. The cadence is stored in `user://ads_state.json`, separate from the player
save.

## 4. Android build requirements

The plugin needs a **Gradle build**; the plain Android export template cannot include the AARs.

1. Install **OpenJDK 17**, Android **SDK Platform 35**, **Build-Tools 35.x**, **Platform-Tools**,
   and the **NDK/CMake** versions used by Godot 4.5 (NDK 28.1 / r28b). Point Godot's editor
   settings at the JDK and Android SDK.
2. Install the **Godot 4.5+ Android export templates** matching the editor version.
3. If the project previously used a Godot 4.3 build template, delete `res://android/build` and
   reinstall the Android build template from the 4.5+ editor (Project → Install Android Build
   Template).
4. In **Project → Export → Android**, keep **Use Gradle Build** enabled. The plugin adds:
   - `poing-godot-admob-ads-{debug,release}.aar`
   - `poing-godot-admob-core-{debug,release}.aar`
   - `com.google.android.libraries.ads.mobile.sdk:ads-mobile-sdk:1.2.1`
   - `androidx.constraintlayout:constraintlayout:2.2.0`
   - the `com.google.android.gms.ads.APPLICATION_ID` manifest entry, using the `[admob]` app ID.
5. Internet and network-state permissions are already enabled in `export_presets.cfg`. The AdMob
   AAR also declares `android.permission.AD_ID`; keep it unless you intentionally ship a
   non-advertising build.
6. Export the **Android AAB** preset for Play (release, signed) and the **Android** preset for the
   debug/test APK.

Example commands (adjust the Godot path):

```bash
# Debug APK: uses Google's test ad units
godot --headless --path . --export-debug "Android" "build/android/duct-tape-protocol-debug.apk"

# Release AAB: uses the live unit IDs
godot --headless --path . --export-release "Android AAB" "build/android/duct-tape-protocol-release.aab"
```

## 5. Play Console

### Store listing

- **Contains ads:** **Yes**. This must match the AdMob integration. A "No" answer is a policy
  violation.
- **Privacy policy:** use the public hosted policy at
  `https://boyoapps-pages.pages.dev/duct-tape-protocol/privacy/` and paste it into the listing.
  Keep `PRIVACY.md` in the repository as the source. The same site can host `app-ads.txt` at the
  domain root (`https://boyoapps-pages.pages.dev/app-ads.txt`).
- **App category / content rating:** complete the IARC questionnaire and declare that the app
  contains ads. Keep the AdMob maximum content rating consistent with the IARC result.
- **Target audience:** not primarily child-directed; do not opt into Families if the game is not
  designed for it. Ads are not child-directed and no Families-certified SDK configuration is used.

### Data safety

The AdMob SDK processes data even though the game has no account. Answer conservatively and keep
the answers consistent with `PRIVACY.md` and Google's current AdMob Data safety guidance:

| Data type | Collected | Shared | Purpose |
|---|---|---|---|
| Device or other IDs (advertising ID) | Yes | Yes | Advertising/marketing, fraud prevention |
| Approximate location | Yes | Yes | Advertising/marketing |
| App activity (ad interactions) | Yes | Yes | Advertising/marketing, analytics |
| Diagnostics (crash/performance) | Yes | Yes | Analytics, fraud prevention |

- **Encrypted in transit:** Yes.
- **Data deletion:** the game itself stores only local save data, which is removed by clearing app
  storage or uninstalling. For advertising data, users can reset/delete the advertising ID in
  Android settings and use **PRIVACY OPTIONS** where available. If Play asks for a deletion request
  URL, use the GitHub issues page
  (`https://github.com/stfleurs/duct-tape-protocol/issues`) and explain the local-data behaviour
  there.
- Re-check the Data safety form after every SDK update; Google occasionally changes what the SDK
  collects.

### app-ads.txt

AdMob expects this line on the developer website you list in Play:

```text
google.com, pub-7279753852255468, DIRECT, f08c47fec0942fa0
```

Host it at `https://boyoapps-pages.pages.dev/app-ads.txt` (the **root** of the domain entered in
the Play listing), not in a subfolder such as `/duct-tape-protocol/`. Then verify it in AdMob
**App settings → app-ads.txt**.

## 6. AdMob policy checklist

- No ads during gameplay. Interstitials only on the results screen after the player taps
  **NEXT**/**RETRY**, and skipped after a rewarded ad.
- Interstitials are capped at one per three finished shifts and 180 seconds, with the count
  persisted across launches.
- Rewarded ads are opt-in, clearly labelled with the reward ("2X SCRAP"), and the reward is granted
  only from Google's `on_user_earned_reward` callback. Closing early grants nothing.
- No "watch this ad or you cannot continue", no forced interstitial on launch/exit, and no ad
  disguised as a game button.
- No banner near the bottom interactive row. The banner is off by default; if enabled, the menu
  moves its bottom row up (`bottom_offset` in `main_menu.gd`).
- Never click live ads during development. Debug builds use Google's sample units; register the
  device as a test device in AdMob if you need to test live units.
- Do not encourage clicks on banners or interstitials; only rewarded video may offer an in-game
  reward.
- Keep the privacy policy, consent message and Data safety answers accurate. Publish the UMP
  message before the release build.
- Do not use the game to promote illegal, gambling or adult content in a way that conflicts with
  the configured AdMob content rating.

## 7. 16 KB page size (Android 15+ requirement)

Google Play requires new apps and updates targeting Android 15 (API 35) to support **16 KB memory
pages**. This repository targets SDK 35, so this must be verified before the first public upload.

- Godot **4.3** ships Android templates built with NDK 23 and an older Android Gradle Plugin. These
  are **not** expected to be 16 KB-aligned. The Godot engine's `libgodot_android.so` is the likely
  blocker, not the AdMob SDK (the GMA Next-Gen SDK is Java/Kotlin and does not add native
  libraries).
- Godot **4.5+** added 16 KB page-size support and moved to NDK 28.1 / AGP 8.6.1
  (godotengine/godot#106358). This is the recommended path.

**Recommended fix (4.5+):**

1. Open the project in **Godot 4.5 or newer** and install the matching **Android export
   templates**.
2. If a custom Android build is installed under `res://android/build`, delete `android/build` and
   reinstall it from the new templates (**Project → Install Android Build Template**). Do not keep
   a build template generated by 4.3.
3. Export the **AAB** with `versionCode 6` (`Android AAB` preset) and sign it with the same upload
   key used for the existing Play listing.
4. Verify the artifact before upload:

   ```bash
   zipalign -c -P 16 -v 4 app.aab
   ```

   Every `lib/arm64-v8a/*.so` must be 16 KB-aligned. Also inspect each `PT_LOAD` segment with
   `llvm-objdump -p` or Android Studio's APK Analyzer (alignment must be at least `0x4000`). If
   `zipalign` does not inspect inside the AAB on your toolchain, build the test APKs with
   `bundletool build-apks` and run the same check on them.

- Upload the AAB to the Play Console **internal testing** track; the pre-launch report and the
  "16 KB page size" warning are the final check.
- If a Godot 4.3 template is mandatory, budget time for a custom template build with NDK r27+ and
  16 KB linker flags (`-Wl,-z,max-page-size=16384`) plus a 16 KB-capable AGP, then re-test ads,
  touch input and audio on a 16 KB device/emulator.

Do not publish the v0.5 build until this check passes. A build that targets SDK 35 but is not
16 KB-aligned can be rejected or blocked from updates.

## 8. Release test plan

1. Install the **debug** APK on a real Android device with Google Play services.
2. Launch with `DEBUG_EEA_CONSENT = true`; confirm the consent form appears, accepts, and that
   **SETTINGS → PRIVACY OPTIONS** reopens it after accepting.
3. Finish three shifts; the first interstitial should appear only after tapping **NEXT** on the
   third results screen. Finish more shifts quickly and confirm the 180-second gap.
4. On a results screen, tap **WATCH AD: 2X SCRAP**; confirm the test ad plays, the reward is
   granted once, and closing early grants nothing.
5. Start a shift, background the app, return, and finish it; confirm no ad appears mid-shift and
   progress is intact.
6. Install the **release** AAB through an internal testing track (or a release APK signed with the
   upload key) and repeat steps 3–4 with live units. Never click your own live ads — use the
   AdMob test-device setting or a test unit for click tests.
7. Check logcat for `AdManager:` warnings; a healthy flow has no repeated `failed to load` lines.
