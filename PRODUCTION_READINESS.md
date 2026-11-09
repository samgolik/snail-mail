# production readiness

This is the launch gate for snail mail. A checked item should be backed by a
repeatable test, production-console evidence, or a shipped build—not optimism.

## shipped in TestFlight build 6

- Letter opening now presents an immediate, intentional seal-breaking state.
- Auth and App Check credentials are prepared concurrently for callable API requests.
- `openLetter` uses concurrent Firestore reads and one idempotent update instead of a transaction.
- Sending returns the new letter directly instead of reloading the whole home payload.
- Home profile lookups use one batched Firestore RPC as the address book grows.
- The app no longer polls the complete home payload every 60 seconds. It refreshes
  on launch, foreground, pull-to-refresh, and meaningful push events.
- Callable diagnostics include total request duration without logging identities,
  tokens, phone numbers, locations, or letter contents.
- Firebase Crashlytics and release dSYM upload are configured. The privacy policy
  now discloses crash diagnostics.
- Public web links have one `SnailPublicSiteURL` configuration point, so changing
  to a branded domain no longer requires editing several screens.

## implemented for App Store candidate version 1.1 build 7

- New accounts receive a short, skippable introduction before creating their
  snailing address; returning accounts never see it.
- Navigation, tabs, titles, actions, and letter content use a consistent SF
  Rounded type system without adding a third-party font or font-license risk.
- Phone verification begins silent APNs registration at launch, and auth buttons
  explain whether the app is preparing or checking a code.
- Friend requests and letter sending show immediate, action-specific progress.
  Callable requests stop with a retryable error after 12 seconds instead of
  appearing to spin indefinitely.
- A resolved current city is reused for ten minutes in memory, reducing repeated
  GPS and reverse-geocoding work without persisting coordinates.
- `openLetter` fetches the letter metadata and sealed body in one Firestore batch
  read. Letter, friend, and acceptance pushes are queued outside the interactive
  request path, with zero warm instances, bounded concurrency, and retry limits.

The iOS and Functions code above passed the local automated checks. Build 7 and
the matching Functions release are promoted together so the client never
depends on an undeployed callable contract.

## must pass before public launch

### reliability and performance

- Verify a clean Release archive with Xcode 26 and run `./testflight-check.sh`.
- On two physical phones, measure cold launch, warm launch, home load, friend
  search, send, and open-letter duration on Wi-Fi and cellular. Target a visible
  response within 100 ms, ordinary API completion under 1 second warm, and a clear
  retry state by 10 seconds. Record p50 and p95 rather than one good run.
- Confirm Crashlytics receives one deliberate non-production test crash and that
  its stack trace is symbolicated. Remove the deliberate crash before release.
- Run the emulator integration suite and manually test offline/reconnect, expired
  auth, denied location, disabled Background App Refresh, push denied, and rapid
  repeated taps.
- Load-test the callable boundary with a small controlled workload before changing
  the current two-instance cost ceiling. Do not create minimum instances until
  measurements show cold starts are a material p95 problem and a monthly cost is approved.
- Add pagination before any account can accumulate more than the current 100 sent
  or 100 received records returned by `loadHome`.

### product and safety

- Finish the App Review demo path with two dedicated phone-auth accounts, an
  accepted friendship, one traveling letter, and one already-arrived letter.
- Test report, block, unblock, remove friend, and account deletion end-to-end in
  production. Establish a documented inbox and response process for safety reports.
- Decide retention periods for letters, reports, server logs, invalid push tokens,
  and deleted-account backups; update the policy to state concrete periods.
- Add rate-limit and error-rate alerts, Crashlytics alerts, and a billing budget
  alert to `beattheclockstudios@gmail.com`. A budget alert is not a hard cap.
- Create a rollback runbook and retain the last known-good TestFlight build.

### privacy and App Store

- Correct App Store privacy answers: phone number, coarse location, user content,
  user ID, crash data/diagnostics, push token, and security/attestation data are
  processed; there is no tracking or advertising.
- Confirm every production dependency's privacy manifest is included in the
  archive and review Firebase disclosures again immediately before submission.
- Have the Terms, Privacy Policy, Community Guidelines, moderation process, and
  account-deletion behavior reviewed for the launch regions.
- Complete accessibility QA with VoiceOver, Reduce Motion, Bold Text, Increase
  Contrast, and the largest Dynamic Type sizes on a small and large iPhone.

## branded domain plan

The current public site is `snail-mail-btc.web.app`. The repository is ready to
switch through `SnailPublicSiteURL`, but no branded domain currently resolves.
Choose and register a domain first; a restrained option is
`snailmail.beattheclockstudios.com` if `beattheclockstudios.com` is acquired.

Then:

1. Connect the domain under Firebase Hosting and add the DNS records Firebase provides.
2. Wait until Firebase reports the SSL certificate as connected.
3. Add the host to Firebase Authentication's authorized domains.
4. Change `SnailPublicSiteURL` in both app Info plists and update App Store Connect URLs.
5. Configure an Associated Domains entitlement and an `apple-app-site-association`
   file so friend links open the app as universal links, with the custom URL scheme
   retained as a fallback.
6. Re-test phone authentication with Background App Refresh both on and off.

Firebase phone authentication normally verifies a physical device with silent
APNs. If silent verification is unavailable, Firebase must fall back to a web
reCAPTCHA flow, which can expose the Firebase project hostname. The fallback
cannot simply be removed without breaking sign-in for some users; production
APNs configuration should make it uncommon.

## next architecture work after launch validation

- Replace the monolithic `loadHome` response with paginated mailbox/archive calls
  and a small connection summary.
- Cache only non-sensitive mailbox metadata for instant relaunch; keep sealed
  letter bodies memory-only unless an encrypted offline-reading product decision
  is made.
- Add server-side latency distributions and structured error dashboards before
  tuning regions or instance counts.
- Consider an authenticated universal-link invitation flow after the branded
  domain is live.

