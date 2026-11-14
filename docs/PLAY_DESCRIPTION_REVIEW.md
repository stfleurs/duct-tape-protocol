# Play description correction - DRAFT FOR STEEVE'S REVIEW

No Play Console changes have been made. These words describe the current v0.5.0 app, not the experimental triage shift.

## Required correction

Replace the final two feature bullets:

- Plays fully offline, no account needed
- No ads and no data collected

with:

- No account required; your game progress is stored on your device
- Contains ads, including optional rewarded ads to double a shift's scrap
- Google's advertising services may collect and share data, including device identifiers, app activity, diagnostics and approximate location. See the privacy policy for details

Keep the existing privacy-policy link. This wording does not replace or certify the Play Data safety form. The form and SDK configuration need to remain accurate for the released app.

## Two other accuracy corrections found while checking the description

Replace:
"Chain reactions: leave a problem too long and things start breaking all at once"
with:
"Chain reactions: fixing one malfunction can set off another"

Replace:
"Earn up to 3 stars per shift: finish, beat the par time, keep the ship healthy"
with:
"Earn up to 3 stars per shift: finish, beat the par time, and keep 70% ship health or build a x5 combo"

## Grounding

Listing checked 14 November 2026:
https://play.google.com/store/apps/details?id=com.boyoapps.ducttapeprotocol

It says "Contains ads" and discloses collection/sharing of Location, App activity and two other categories, but the description still says "No ads and no data collected".

Source checked: public repository at 4910b19129ff274bcef2eb2ad7814de47decab05, version 0.5.0. Source version matches the listing, but the store's AAB bytes were not verified.

- scripts/ad_manager.gd: AdMob, rewarded / interstitial / app-open placements
- PRIVACY.md: local save data and advertising-services data handling
- scripts/level_manager.gd: repair-triggered chain queue
- scripts/score_manager.gd: finish + par + (health or combo) star logic

No claim of "no collection" or "no sharing" should be restored merely because local progress stays on-device. Ad services are separate.
