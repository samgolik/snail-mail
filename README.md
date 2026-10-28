# Snail Mail MVP

A local SwiftUI vertical slice for delayed messages. It includes two demo profiles, a mailbox, composition, distance-based travel time, sealed letters, accelerated debug delivery, JSON persistence, and unit tests.

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

## Demo flow

1. On **Write**, send a letter from Sam to Alex.
2. Open **Demo** and switch to Alex.
3. Open **Mailbox** and watch the snail travel.
4. The DC-to-NYC journey takes about 45 seconds in a debug build.
5. Open the letter after it moves to **Arrived**.

Run unit tests with **Product → Test** (`⌘U`) or:

```sh
xcodebuild test -project SnailMail.xcodeproj -scheme SnailMail \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

## Production note

Release builds use real days. Before inviting real users, replace local persistence with authentication and a server that withholds message bodies until arrival. Client-side hiding alone is not secure.
