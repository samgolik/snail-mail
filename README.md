# snail mail

A SwiftUI beta for delayed messages. It includes Firebase email/password sign-up,
sign-in, password reset and verification; server-backed profiles and friend
requests; editable return addresses; cross-device mailboxes; server-calculated
travel time; sealed letters; reporting and blocking; permanent account deletion;
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
- An Apple ID already configured for development signing in the installed Xcode toolchain
- Your Apple development team ID

Then run:

```sh
cd /path/to/SnailMail
TEAM_ID=YOUR_TEAM_ID ./run-device.sh
```

The script finds the connected iPhone, builds with automatic signing, installs,
and launches the app. A free Apple ID is sufficient for personal-device testing,
though its development provisioning expires sooner than paid-account provisioning.

To find your team ID, check an existing development provisioning profile or your
Apple Developer account. If signing has never been configured on this Mac, the
command-line tools alone cannot add the Apple ID; that one-time setup must be done
with a compatible Xcode installation or on another Mac using the same account.

## Product flow

1. Create an account and verify its email.
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
- Validated reporting and blocking tied to real connections or letters
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
- iOS products linked: Core and Authentication
- Firestore and Functions backend configuration is retained but their unused,
  heavyweight iOS SDK products are intentionally not linked for the first beta
- Firestore rules and mailbox indexes: deployed
- Firebase Authentication: anonymous and email/password enabled

The current rules are intentionally closed to direct client access. Production
reads and writes go through authenticated callable functions so profiles cannot
be enumerated, friendships cannot be forged, and letter metadata cannot be
tampered with. Backend changes made after the last deployment require
`firebase login --reauth` and a reviewed deploy before production testing.

The app opens on an email/password welcome flow. A signed-in user creates a
return address, exchanges private friend codes, accepts connections, and sends
cross-device letters whose bodies remain in a server-only collection until
arrival. Password reset, verification, sign-out, and permanent account deletion
are available in-app.

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
CHOKIDAR_USEPOLLING=1 npx -y firebase-tools@latest emulators:start
```

The backend integration test creates two disposable emulator accounts and
exercises profile setup, verified friend requests, sealed sending, early-open
rejection, reporting, blocking, rate-limit enforcement, and account deletion:

```sh
cd firebase/functions
npm run test:integration
```

Run it while the Auth, Firestore, and Functions emulators are active. On this
older Intel Mac, `CHOKIDAR_USEPOLLING=1` prevents the Functions watcher from
exhausting file descriptors.

The app and local backend are connected and the full emulator integration test
passes. The remaining cloud release step is to reauthenticate the Firebase CLI,
confirm the project billing/budget settings, and deploy the reviewed Functions,
rules, indexes, and Hosting pages. See `TESTFLIGHT.md` and `OPERATIONS.md`.

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
