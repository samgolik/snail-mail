# Snail Mail MVP

A local SwiftUI vertical slice for delayed messages. It includes two demo profiles, a mailbox, composition, distance-based travel time, sealed letters, accelerated debug delivery, JSON persistence, and unit tests.

The interface uses a muted sage, powder-blue, cream, and clay palette with rounded
paper-like cards, restrained snail details, and lowercase copy throughout.

## Run it

1. Open `SnailMail.xcodeproj` in Xcode 16 or newer.
2. Select the `SnailMail` scheme and an iPhone simulator.
3. Press **Run** (`⌘R`).

No Apple Developer account or backend is required for the simulator.

## Run without opening Xcode

If the Xcode command-line tools and an iOS Simulator runtime still work, run:

```sh
cd /path/to/SnailMail
./run-simulator.sh
```

The script finds an available iPhone simulator, builds the app, boots the device,
installs the app, and launches it. Xcode.app must still be installed because its
iOS SDK and build tools are required, but the Xcode IDE does not need to open.

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
