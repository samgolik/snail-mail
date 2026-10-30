# TestFlight and App Store launch checklist

The production code uses bundle ID `com.samgolik.snailmail`. Simulator QA does
not require a paid Apple account; upload and TestFlight distribution do.

## External prerequisites

1. Renew the Apple Developer Program membership.
2. Accept current agreements in Apple Developer and App Store Connect.
3. Create the explicit App ID and App Store Connect record for
   `com.samgolik.snailmail`.
4. Configure Apple signing on a currently supported Xcode installation.
5. Reauthenticate the Firebase CLI with `firebase login --reauth`.
6. Confirm the Firebase project is on a plan that permits Cloud Functions
   deployment and set a budget alert.

## Backend release

Current status: Firestore rules/indexes and Hosting are deployed. Functions are
verified locally but Firebase blocked deployment until `snail-mail-btc` is on the
Blaze plan. Upgrade only with an owner-approved billing account and budget alert.

1. Run `npm ci && npm run check && npm run build` in `firebase/functions`.
2. Run the full emulator integration test documented in `README.md`.
3. Review `SECURITY_AUDIT.json`, Firestore Rules, indexes, and project ID.
4. Deploy with `firebase deploy --only firestore,functions,hosting`.
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
