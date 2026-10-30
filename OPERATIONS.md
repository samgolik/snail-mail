# production operations

This is the minimum runbook for operating the snail mail beta. It is deliberately
small enough for one developer to follow consistently.

## release owner

- Owner: beat the clock studios
- Support and privacy contact: `beattheclockstudios@gmail.com`
- Firebase project: `snail-mail-btc`
- Bundle ID: `com.samgolik.snailmail`

Never place passwords, ID tokens, letter contents, private keys, or unredacted
user exports in issues, logs, screenshots, or source control.

## before every release

1. Run `./testflight-check.sh` and the emulator integration test in `README.md`.
2. Review the Firebase diff, especially callable authorization and deletion.
3. Confirm the public privacy and support URLs work without signing in.
4. Confirm Firebase billing alerts, usage dashboards, and App Store agreements.
5. Increment the Xcode build number, archive, validate, and upload.
6. Exercise the release build with two non-personal review accounts before
   inviting external testers.

## safety reports

The app stores reports in the private `reports` collection with `status: open`.
During TestFlight, check open reports at least once each day that testers are
active. Target review times are 24 hours for threats, harassment, sexual content,
or credible safety concerns and three business days for other reports.

For each report:

1. Confirm the reporter, target, and optional letter ID are internally consistent.
2. Read only the minimum data needed to evaluate the report.
3. Preserve evidence when there is a credible safety or legal concern.
4. Take the least invasive effective action: document no action, warn, disable,
   or delete the offending account through Firebase Authentication and related
   data through an audited admin procedure.
5. Record the decision and set the report status to `resolved` with a timestamp.
6. Reply to the reporter only when needed; never reveal their identity to the
   reported user.

Blocking is immediate and self-service. It removes the friendship and prevents
new friend requests or letters in either direction. The blocker can privately
review and unblock accounts under **you**; unblocking never restores a friendship
without a new accepted request.

## privacy and deletion requests

In-app deletion is the primary path and removes the Firebase Auth identity,
profile, username and friend-code reservations, friendships, blocks, letters,
and sealed bodies. Safety reports authored by the account are removed. Reports
about an account may be retained when needed for abuse prevention or legal
compliance; disclose that retention when responding to a manual request.

If a user cannot access the app, require a request from the account email and
verify ownership before any manual action. Do not send raw database exports by
ordinary email. Record the request date, verification, action, and completion.

## outage and incident response

1. Confirm whether Auth, Firestore, Functions, or Hosting is affected in the
   Firebase console and Google Cloud status dashboard.
2. Pause tester invitations if signup, sealed delivery, authorization, or
   deletion is unreliable.
3. For suspected data exposure, preserve logs, rotate affected credentials,
   disable the vulnerable function or release, and determine impacted users.
4. Notify affected users and regulators when required by applicable law.
5. Write a short post-incident note with cause, scope, remediation, and a test
   that prevents recurrence.

The app keeps already-loaded mailbox metadata visible during transient refresh
failures and provides an explicit retry. It must never weaken authorization or
release sealed contents to compensate for an outage.

## rollback

- iOS: stop the TestFlight build from accepting new testers and submit a fixed
  build; App Store binaries cannot be replaced in place.
- Functions: redeploy the last reviewed commit. Do not roll back Firestore rules
  to a version that permits direct client access.
- Hosting: redeploy the last reviewed privacy/support pages.
- Data: prefer forward repairs. Restore or rewrite user data only after making a
  backup and documenting the exact affected document IDs.

## post-launch hardening

App Check is integrated in the client and required by production callables. Before
the first Functions deployment, finish the owner-controlled Firebase App Attest
registration, Apple capability/production entitlement, and simulator debug-token
registration. Never commit a debug token. Also confirm production usage alerts.
Authenticated write actions already have server-side daily limits. Add push
notifications only after the Apple signing/APNs setup is available. These are not
allowed to delay account deletion, reporting, blocking, or security fixes.
