# snail mail

A SwiftUI beta for delayed messages. It includes passwordless Firebase phone
signup and sign-in with one-time SMS codes; server-backed profiles and friend
requests; editable return addresses; removable connections and manageable blocks;
cross-device mailboxes; server-calculated travel time; sealed letters; reporting;
permanent account deletion;
launch recovery; and automated backend coverage.

The interface uses an adaptive muted sage, powder-blue, cream, and clay palette
with rounded paper-like cards, a hand-drawn journey snail, full Dark Mode
contrast, Reduce Motion support, and lowercase copy throughout.
The asset catalog includes a full-resolution, full-bleed snail-and-envelope app
icon ready for TestFlight packaging.

## Run it

1. Open `SnailMail.xcodeproj` in Xcode 16 or newer.
2. Select the `SnailMail` scheme and an iPhone simulator.
3. Press **Run** (`⌘R`).

No Apple Developer account is required for the simulator. Firebase Auth is
configured locally; production social flows also require the callable backend
in `firebase/functions` to be deployed.

## Run without opening Xcode

If the Xcode command-line tools and an iOS Simulator runtime still work, run:

```sh
cd /path/to/SnailMail
./run-simulator.sh
```

The script finds an available iPhone simulator, builds the app, boots the device,
installs the app, and launches it. Xcode.app must still be installed because its
iOS SDK and build tools are required, but the Xcode IDE does not need to open.
It automatically builds only the host simulator architecture (`x86_64` on an
Intel Mac and `arm64` on Apple silicon), avoiding mixed-architecture Firebase
module errors. Keep normal simulator signing enabled: Firebase Authentication
stores its session in the Keychain, and explicitly disabling code signing can
prevent that secure storage from working. If a connection attempt fails, open
the app now shows a dedicated retry screen instead of mistaking an outage for a
new account.

Quickly diagnose the toolchain with:

```sh
xcode-select -p
xcodebuild -version
xcrun simctl list devices available
```

## Run on a physical iPhone without the Xcode IDE

This is usually faster than the Simulator on an older Mac. You need:

- An iPhone connected by USB and unlocked
- Developer Mode enabled under **Settings → Privacy & Security → Developer Mode**
- The Mac trusted when the iPhone asks
- The Beat the Clock Apple Development certificate and the
  `Snail Mail iPhone Development` profile installed on the Mac

Then run:

```sh
cd /path/to/SnailMail
./run-device.sh
```

The script finds the connected iPhone, builds with the app target’s manual
development profile, installs, and launches the app. The paid Beat the Clock team
is preferred when it is present in Xcode’s saved team list. Override the detected
team or bundle ID with `TEAM_ID=... DEVICE_BUNDLE_ID=... ./run-device.sh`.

Debug builds use Firebase’s debug App Check provider. Each installation keeps a
private token on the device; that token must be registered in Firebase App Check,
and the Firebase App Check API must remain enabled for `snail-mail-btc`. Never
share the token or distribute a Debug build. Release continues to use the App
Store bundle ID and production App Attest entitlement.

Firebase Auth app-delegate swizzling is disabled for the SwiftUI lifecycle. A
`UIApplicationDelegateAdaptor` explicitly forwards the APNs device token,
phone-auth silent notification, and reCAPTCHA callback URL to Firebase Auth.
The SwiftUI scene also forwards opened URLs with `onOpenURL`, because reCAPTCHA
redirects are delivered through the scene lifecycle on modern iOS versions.
Release signing includes production APNs and background remote-notification
support so Firebase can usually verify a physical device silently; reCAPTCHA
remains the required fallback.

Every text-entry screen exposes a keyboard **done** control and supports
interactive dismissal while scrolling. Return-address entry accepts a human
friendly `city, region` query, then geocodes and stores a canonical city/region
label with approximate coordinates. The app never requests precise device
location and never exposes coordinates to other users.

## Product flow

1. Enter a mobile number and use its one-time SMS code to create an account or sign in.
2. Make a return address with a display name, username, and city.
3. Exchange friend codes and accept the incoming request.
4. Write a letter; the server seals its body and calculates arrival.
5. The recipient watches it travel and can open it only after server time passes.

Run unit tests with **Product → Test** (`⌘U`) or:

```sh
xcodebuild test -project SnailMail.xcodeproj -scheme SnailMail \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

## Delivery model

Release builds use real days, capped at 30. Delivery is enforced by server time:
the mailbox response never includes a letter body, and only the authenticated
recipient can request the separately stored body after arrival. Changing a
device clock or modifying the client cannot open a letter early.

## Firebase backend foundation

The `firebase/` directory contains the first production backend boundary:

- Firestore rules that deny all direct client access
- Completely private `sealedLetters` documents
- A callable `sendLetter` function that verifies friendship and calculates arrival using server time
- A callable `openLetter` function that releases the body only to the recipient after arrival
- Callable profile setup, unique friend codes, friend request/acceptance, and mailbox bootstrap
- Validated reporting, reversible blocking, and connection removal
- Versioned Terms of Use and Community Guidelines acceptance before social actions
- Private profile shaping so friend codes and delivery coordinates are never returned to other accounts
- Per-account daily limits for profile edits, friend requests, letters, and reports
- Complete in-app account deletion that removes friendships, letters, sealed bodies, profile reservations, and Firebase Auth identity
- Firestore indexes for sender and recipient mailboxes
- Local Auth, Firestore, and Functions emulator configuration

The iOS app is registered with Firebase and uses Firebase Authentication plus a
narrow callable HTTPS API. Firestore is not directly accessible to the client.

Current Firebase registration:

- Project: `snail-mail-btc`
- iOS bundle ID: `com.samgolik.snailmail`
- Firestore: Standard edition, default database, `us-east1`
- Firebase Apple SDK: `12.19.3` (pinned for Xcode 16.4 / Swift 6.1 compatibility)
- iOS products linked: Core, Authentication, and App Check
- Firestore and Functions backend configuration is retained but their unused,
  heavyweight iOS SDK products are intentionally not linked for the first beta
- Firestore rules and mailbox indexes: deployed
- Privacy/support Hosting site: deployed at `https://snail-mail-btc.web.app`
- Callable Functions: all 12 deployed on Node 22 in `us-east1`, with bounded
  beta scaling and one-day cleanup of stale deployment images
- Firebase Authentication: phone enabled; email/password and anonymous accounts disabled

The current rules are intentionally closed to direct client access. Production
reads and writes go through authenticated callable functions so profiles cannot
be enumerated, friendships cannot be forged, and letter metadata cannot be
tampered with. Outside the emulator, every function also requires a verified
Firebase App Check token. The app sends App Check in the callable protocol header,
uses a debug provider in Debug builds, and uses App Attest in Release builds.
The production App Attest entitlement is checked in and linked to both app build
configurations. After the Apple team is active, the owner must enable the matching
App Attest capability for the App ID and register App Attest in Firebase. The app’s
profile, friendship, and letter screens require that owner-controlled setup before
production device testing; the callable Functions are already live.

The app opens on a phone-number welcome flow. A verified number creates a new
account or returns to its existing account without a password. A signed-in user creates a
return address, exchanges private friend codes, accepts connections, and sends
cross-device letters whose bodies remain in a server-only collection until
arrival. Sign-out and permanent account deletion are available in-app.

`GoogleService-Info.plist` is required locally but intentionally ignored by Git.
After a fresh clone, download it for the registered iOS app before building.

### Local backend setup

Install Node.js 22 and the Firebase CLI, then:

```sh
cd firebase/functions
npm install
npm run check
npm run build
cd ../..
./run-backend.sh
```

Keep that terminal running while using the simulator. Debug simulator builds
automatically use Auth on `127.0.0.1:9099` and callable Functions on
`127.0.0.1:5001`; Release and physical-device builds always use production.
The Xcode Debug configuration defines Swift's `DEBUG` compilation condition so
the app cannot silently route to the undeployed production Functions endpoint.
It is deliberately configured at the project level rather than passed globally
to `xcodebuild`, which preserves Firebase packages' own compilation conditions.
The explicit Debug Info.plist alone permits local HTTP traffic for those
emulators; the separate Release Info.plist remains HTTPS-only.
Because emulator accounts are separate from production, create a fresh local
account the first time. Debug simulator authentication uses a separately named
Firebase app, giving it a distinct keychain namespace from production while
still preserving local sessions normally. If a previous emulator session left a
port occupied, stop that old process before restarting the complete suite.

`run-simulator.sh` refuses to install the app unless Auth, Firestore, and
Functions are listening locally. After building, it also inspects the compiled
Debug Info.plist and refuses installation if the local-network exception is
missing. This turns a disconnected build into a terminal error instead of the
ambiguous in-app “post office is out of reach” state.

To watch safe client diagnostics in a third terminal while reproducing a
connection problem:

```sh
./debug-logs.sh
```

Each callable request gets a short diagnostic ID that also appears on the
in-app error screen. The log records authentication preparation, local App
Check behavior, network status, HTTP status, and response decoding without
printing passwords, Firebase tokens, user IDs, or letter contents. Match the
on-screen ID to the terminal line to find the exact failing stage.

The backend integration test creates two disposable emulator accounts and
exercises profile setup, verified friend requests, sealed sending, early-open
rejection, reporting, block/unblock, reconnect/removal, rate-limit enforcement,
and account deletion:

```sh
cd firebase/functions
npm run test:integration
```

Run it while the Auth, Firestore, and Functions emulators are active. On this
older Intel Mac, `CHOKIDAR_USEPOLLING=1` prevents the Functions watcher from
exhausting file descriptors.

The app and local backend are connected and the full emulator integration test
passes. Firestore rules/indexes, Hosting, and all 12 production Functions are
live. Functions use the conservative beta scaling limits documented in
`DECISIONS.md`, and stale deployment images are removed after one day. Use
`deploy-functions.sh` for reviewed backend releases. See `TESTFLIGHT.md` and
`OPERATIONS.md` for release procedures.

Cloud configuration and deployment are intentional account-level actions and are not performed by this repository automatically.

## TestFlight readiness

Run the local preflight check with:

```sh
./testflight-check.sh
```

Uploading to TestFlight still requires an active Apple Developer Program
membership, an Apple Distribution signing identity, and an App Store Connect
app record for bundle ID `com.samgolik.snailmail`. The repository can be built
and tested in the simulator without those credentials. See `TESTFLIGHT.md` for
the shortest upload checklist and draft beta metadata.
