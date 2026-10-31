# product and engineering decisions

This is the running record of consequential choices made while building snail
mail. Each entry records the current decision, why it was made, and what would
justify revisiting it. It is not a substitute for the release checklist or
operations runbook.

## 2026-10-30 — first hosted beta backend preparation

### use the verified phone number as the complete account identity

- **Decision:** Signup, verification, and returning sign-in all use the same
  one-time SMS flow. The app does not request an email address or password.
- **Why:** A single phone-first flow is the intended product model and removes
  the confusing distinction between creating an account and later verifying
  it. The number remains private and friends never receive it.
- **Cost and abuse controls:** SMS is restricted in Firebase to United States
  numbers for the first beta. The app discloses that Google receives the number
  for authentication, spam prevention, and abuse prevention. Broader country
  support should be a deliberate expansion because every SMS can incur Blaze
  usage.
- **Implementation:** Production Functions require Firebase's `phone_number`
  authentication claim for friendship and letter-writing actions. Local
  emulator tests temporarily accept their existing verified-email fixtures.
- **Migration:** Existing beta accounts that already linked a phone number keep
  their Firebase UID and can sign in with that number. Email-only beta accounts
  must be recreated or migrated manually before launch.
- **Revisit when:** Testers need international numbers. Before launch, document
  recovery and recycled-number handling because there is no email fallback.

### bridge Firebase Auth through the SwiftUI app delegate explicitly

- **Decision:** Disable Firebase app-delegate swizzling and attach a dedicated
  `UIApplicationDelegateAdaptor` that forwards the APNs token, silent phone-auth
  notification, and reCAPTCHA callback URL to Firebase Auth.
- **Why:** Firebase requires the explicit delegate bridge for SwiftUI phone
  authentication. A single manual path is more predictable than combining a
  SwiftUI lifecycle with automatic method swizzling.
- **Fallback:** If silent APNs verification is unavailable, Firebase uses the
  registered custom URL scheme to complete reCAPTCHA verification.

### blaze is active and the guarded backend is live

- **Observed:** The first deployment correctly failed while the project was
  still on Spark. After Sam completed the upgrade, Firebase enabled the required
  APIs and all 11 Node 22 Functions became active in `us-east1`.
- **Verified:** The deployed configuration reports 256 MiB memory, fractional
  CPU, 30-second timeout, maximum two instances, and concurrency one. A single
  unauthenticated smoke request returned `401 app verification failed`.
- **Decision:** Keep deployment explicit and code-driven through
  `deploy-functions.sh`. Do not manipulate billing or add services as part of a
  routine deploy.
- **Cost hygiene:** Artifact Registry deletes stale Function images after one
  day. This avoids the small storage charge Firebase warned about after the first
  deploy.
- **Owner follow-up:** Confirm a billing budget alert reaches
  `beattheclockstudios@gmail.com`; alerts are not hard spending caps.

### ship the reviewed callable backend on Firebase

- **Decision:** Run the authenticated callable Functions in `snail-mail-btc` in
  `us-east1`.
- **Why:** TestFlight cannot depend on a laptop-hosted emulator. The callable
  boundary already centralizes authorization, sealed-letter access, moderation,
  deletion, rate limits, and server-controlled delivery time.
- **Revisit when:** Production usage or latency supports a different region or
  architecture. Do not add a second region casually because it multiplies
  infrastructure and can complicate consistency.

### optimize the beta for cost safety, not burst capacity

- **Decision:** Every Function uses 256 MiB memory, fractional Gen 1-style CPU,
  a 30-second timeout, zero minimum instances, a maximum of two instances, and
  one concurrent request per instance.
- **Why:** Zero minimum instances avoids idle compute charges. A small ceiling
  bounds accidental scale while the tester group is small. Cold starts and
  modest queueing are acceptable for this deliberately slow product.
- **Tradeoff:** The API may feel briefly slower after inactivity and can reject
  or queue bursts. That is preferable to surprise spend during the first beta.
- **Revisit when:** Measured TestFlight traffic shows sustained capacity or
  timeout problems. Raise one limit at a time with a documented reason.

### keep App Check mandatory in production

- **Decision:** Production callable handlers continue to reject requests without
  verified App Check context. Local emulators bypass that requirement.
- **Why:** Auth proves who a user is; App Check helps ensure calls originate from
  the real app. Both matter because direct Firestore access is intentionally
  denied and Functions are the sole data boundary.
- **Revisit when:** Only to repair a verified release-blocking configuration
  issue. Do not weaken this as an outage workaround.

### keep the MVP relationship model invitation-only

- **Decision:** Friends connect using private friend codes. Do not add public
  user search, contact uploading, or address-book discovery before tester input.
- **Why:** It is simpler, more private, and reduces spam and moderation surface.
- **Revisit when:** Testers consistently report that exchanging codes is the
  main barrier to successful first use.

### retain safety context for old correspondence

- **Decision:** Removing a friendship does not delete old letters. The mailbox
  retains the other participant’s minimal public profile so a received letter
  remains attributable, reportable, and blockable after the connection ends.
- **Why:** A connection ending must not remove safety controls from existing
  user-generated content. This does not restore the friendship or permit new
  letters.
- **Revisit when:** Retention policy changes; preserve the ability to report old
  content even if the UI or storage representation changes.

### keep delivery time server-controlled and capped

- **Decision:** Delivery is calculated by the backend from approximate city
  coordinates, at 15 miles per snail day, with a one-day minimum and 30-day cap.
- **Why:** The delay is the product. Server calculation prevents clients from
  opening letters early, while the cap keeps the mechanic usable.
- **Question for Sam:** After real usage, should the cap remain 30 days, become
  shorter for early beta, or turn into a playful non-linear distance curve?

### defer notifications until Apple signing is available

- **Decision:** Do not add APNs/FCM push notifications before the Apple team,
  App ID, and signing capabilities are restored.
- **Why:** Notifications require owner-controlled Apple configuration and are
  not necessary to validate composing, waiting, arrival, friendship, and safety
  flows.
- **Revisit when:** The first signed TestFlight build is available. The initial
  notification should announce arrival without revealing letter contents.

### separate device development from release attestation

- **Decision:** Debug builds use Firebase App Check’s debug provider and no App
  Attest entitlement; Release builds alone use App Attest. Free-team device builds
  use the separate `com.samgolik.snailmail.dev` identifier.
- **Why:** This enables command-line development on Sam’s physical phone without
  weakening the TestFlight binary or requiring a paid capability for every Debug
  install. The private debug token is generated under ignored `.build/`, registered
  with Firebase, and never embedded in source or Release builds.

### protect the quiet visual identity

- **Decision:** Preserve the restrained paper, clay, green, and powder palette,
  lowercase voice, generous spacing, and postal motifs. Avoid increasing the
  pink/pastel emphasis without explicit design direction.
- **Why:** The current design is warm and distinctive without leaning too
  “girly,” matching the feedback received so far.
- **Question for Sam:** Tester feedback should decide whether the final identity
  leans more vintage post office, storybook snail, or clean modern stationery.

### minimize profile data at the callable boundary

- **Decision:** A user receives their own friend code and approximate delivery
  coordinates, but other accounts receive only display name, username, and city.
- **Why:** The server calculates delivery time, so clients do not need another
  person’s coordinates. Friend codes are invitations, not public identifiers.
- **Verification:** The emulator integration test fails if a friendship response
  contains `friendCode`, `latitude`, or `longitude` for the other account.

### require a versioned community agreement

- **Decision:** Account creation presents the Terms, Community Guidelines, and
  Privacy Policy. The backend records acceptance of version `2026-10-30`; friend
  requests, request responses, and sending remain unavailable until acceptance.
- **Why:** Private messages are still user-generated content. Clear rules,
  reporting, blocking, enforcement expectations, and recorded acceptance are
  part of a responsible social product and App Review readiness.
- **Safety exception:** Reporting, blocking, account deletion, and reading one’s
  mailbox are never withheld because a newer agreement needs acceptance.
- **Deployment:** The twelfth callable, `acceptTerms`, and the public Terms and
  Community pages went live on October 30, 2026. Anonymous authentication is
  disabled, and the backend also rejects anonymous identities defensively.

## prioritized ideas for tester feedback

These are hypotheses, not committed scope:

1. A tiny journey visualization that makes waiting delightful without exposing
   exact locations.
2. Arrival notifications with privacy-safe copy and no message preview.
3. A first-letter onboarding path that gets two friends connected quickly.
4. Optional stationery choices that never alter readability or delivery speed.
5. Gentle correspondence streaks only if they do not create urgency or guilt.

Avoid public feeds, read receipts, typing indicators, infinite discovery, paid
speed-ups, or mechanics that undermine delayed correspondence. The product
should feel calmer than ordinary messaging, not become ordinary messaging with
a snail skin.
