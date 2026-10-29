# Snail Mail MVP

A SwiftUI vertical slice for delayed messages. It includes two demo profiles, a
mailbox, composition, distance-based travel time, sealed letters, accelerated
debug delivery, JSON persistence, Firebase identity, and unit tests.

The interface uses a muted sage, powder-blue, cream, and clay palette with rounded
paper-like cards, restrained snail details, and lowercase copy throughout.
The asset catalog includes a full-resolution, full-bleed snail-and-envelope app
icon ready for TestFlight packaging.

## Run it

1. Open `SnailMail.xcodeproj` in Xcode 16 or newer.
2. Select the `SnailMail` scheme and an iPhone simulator.
3. Press **Run** (`⌘R`).

No Apple Developer account is required for the simulator. The Firebase SDK is
configured, while the current demo data still stays on-device.

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
module errors.

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

## Demo flow

1. On **Write**, send a letter from Sam to Justin.
2. Open **Demo** and switch to Justin.
3. Open **Mailbox** and watch the snail travel.
4. The DC-to-Columbus journey takes about 66 seconds in a debug build.
5. Open the letter after it moves to **Arrived**.

Run unit tests with **Product → Test** (`⌘U`) or:

```sh
xcodebuild test -project SnailMail.xcodeproj -scheme SnailMail \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

## Production note

Release builds use real days. Before inviting real users, replace local persistence with authentication and a server that withholds message bodies until arrival. Client-side hiding alone is not secure.

## Firebase backend foundation

The `firebase/` directory contains the first production backend boundary:

- Firestore rules that make letter metadata readable only to participants
- Completely private `sealedLetters` documents
- A callable `sendLetter` function that verifies friendship and calculates arrival using server time
- A callable `openLetter` function that releases the body only to the recipient after arrival
- Firestore indexes for sender and recipient mailboxes
- Local Auth, Firestore, and Functions emulator configuration

The iOS app is registered with Firebase and initializes the Firebase SDK, while
the visible demo flow still uses its local store. Authentication and live data
sync are the next implementation step.

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

The app signs a new installation in as a private guest automatically. Under
**You**, a tester can save that guest as an email/password account or restore an
existing beta account. Letter content remains in the local demo store for this
checkpoint; cross-device friend delivery is the next product milestone.

`GoogleService-Info.plist` is required locally but intentionally ignored by Git.
After a fresh clone, download it for the registered iOS app before building.

### Local backend setup

Install Node.js 22 and the Firebase CLI, then:

```sh
cd firebase/functions
npm install
npm run check
cd ../..
npx -y firebase-tools@latest emulators:start
```

The remaining production setup is:

1. Enable Authentication and choose the initial sign-in method.
2. Connect the Swift screens to Authentication, Firestore, and callable Functions.
3. Deploy Functions only after reviewing billing and production settings.

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
