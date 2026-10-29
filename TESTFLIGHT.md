# TestFlight launch checklist

The codebase is prepared around bundle ID `com.samgolik.snailmail`. The remaining
upload steps require an active Apple Developer Program membership.

## Fastest path after membership renewal

1. Open the Apple Developer account once and accept any updated agreements.
2. Create or confirm the explicit App ID `com.samgolik.snailmail`.
3. In App Store Connect, create an iOS app named **snail mail** with that bundle ID.
4. On a supported Mac/Xcode installation, add the Apple ID under **Accounts** and
   let Xcode manage signing for the `SnailMail` target.
5. Increment `CURRENT_PROJECT_VERSION` for every upload.
6. Archive the `SnailMail` scheme using **Any iOS Device (arm64)** and choose
   **Distribute App → App Store Connect → Upload**.
7. In App Store Connect, complete export-compliance questions, add the build to
   an internal testing group, and invite testers.

Run `./testflight-check.sh` before archiving. A missing Apple Distribution
certificate is expected until membership and signing are restored.

## Draft beta information

**Beta description**

snail mail is a slower social app for messages worth waiting for. write a letter
to a friend and watch it travel at a fictional snail’s pace before it can be
opened.

**What to test**

- the overall mailbox, writing, and letter-opening flow
- whether the delayed-message idea feels fun or frustrating
- visual tone, readability, and anything that feels too cute or too plain
- account setup under the **you** tab
- bugs, confusing labels, or places where the app feels unfinished

**Current beta limitation**

The first TestFlight build is a design/interaction beta. Firebase accounts are
live, but the Sam-to-Justin correspondence is still a local accelerated demo;
cross-device friend delivery follows in the next milestone.

## Before external testing

- Add a support email and public privacy-policy URL in App Store Connect.
- Explain that Firebase Authentication processes account identifiers.
- Add a simple in-app feedback path.
- Re-run the QA checklist on at least one small and one large iPhone.
- Review the prototype Firestore Security Rules before expanding beyond a small
  invited group.
