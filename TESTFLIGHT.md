# TestFlight and App Store launch checklist

The production code uses bundle ID `com.samgolik.snailmail`. Simulator QA does
not require a paid Apple account; upload and TestFlight distribution do.

## External prerequisites

1. Renew the Apple Developer Program membership.
2. Accept current agreements in Apple Developer and App Store Connect.
3. Create the explicit App ID and App Store Connect record for
   `com.samgolik.snailmail`.
4. Configure Apple signing on a currently supported Xcode installation.
5. Enable App Attest for the App ID after the paid Apple team is active. The
   Release target already links the checked-in `production` entitlement; verify
   Xcode preserves that capability when signing is configured. Debug builds use
   Firebase’s private debug provider and deliberately do not carry App Attest.
6. Register the iOS app under Firebase **App Check** with App Attest. Launch a
   Debug simulator build, copy its generated debug token from the console, and
   register that token without committing it anywhere.
7. Reauthenticate the Firebase CLI with `firebase login --reauth`.
8. Confirm the Firebase project remains on Blaze and that the billing budget
   alert reaches `beattheclockstudios@gmail.com`.

## Backend release

Current status: Firestore rules/indexes and Hosting are deployed. Functions are
verified locally, deployed, and configured with conservative beta cost limits.
All 12 were active on October 30, 2026, and the production endpoints rejected
requests without App Check as designed. Terms and Community pages are live and
anonymous authentication is disabled. Finish the owner-controlled App Attest
registration before distributing the first build and confirm the billing budget
alert reaches the studio email.

1. Run `npm ci && npm run check && npm run build` in `firebase/functions`.
2. Run the full emulator integration test documented in `README.md`.
3. Review `SECURITY_AUDIT.json`, Firestore Rules, indexes, and project ID.
4. Deploy reviewed Function changes with `./deploy-functions.sh`; deploy rules,
   indexes, or Hosting separately only when those files changed.
5. Verify the public privacy and support URLs in `APP_STORE.md`.
6. Create two production review accounts, verify both, connect them, and seed
   an already-arrived review letter.

## iOS release

1. Run `./testflight-check.sh`.
2. QA fresh signup, profile setup, friend requests, delivery, opening,
   profile editing, reporting from both a letter and the address book, blocking,
   password reset, sign-out, launch retry, and account deletion.
3. Test VoiceOver, Dynamic Type, Reduce Motion, light/dark appearance, offline
   errors, a small iPhone, and a current large iPhone.
4. Increment `CURRENT_PROJECT_VERSION` for every upload.
5. Archive Release for **Any iOS Device (arm64)** and validate the archive.
6. Upload to App Store Connect and assign the build to internal TestFlight.
7. Complete metadata and App Privacy answers from `APP_STORE.md`.
8. Confirm the build’s export-compliance answer and age-rating questionnaire.
9. Read `OPERATIONS.md` and assign a person to review reports during the beta.

## Review notes

Delivery is intentionally delayed and enforced using server time. Give App
Review credentials for both prepared accounts and identify the already-arrived
letter so opening can be tested immediately. Explain where report, block, and
delete-account controls live under **you**.
