# MVP QA Pass

## Happy path

- Launch on a fresh simulator and confirm **You** shows `guest` and a beta ID.
- Save the guest with an email and password of at least six characters.
- Relaunch and confirm the saved email remains signed in.
- Sign out and confirm the app returns to a fresh guest without blocking the demo.
- Launch as Sam and confirm both mailbox sections are empty.
- Write a letter to Justin and verify blank messages cannot be sent.
- Confirm the counter prevents messages longer than 500 characters.
- Send, switch to Justin in **Demo**, and open **Mailbox**.
- Confirm the letter is under **Traveling** and its body is not visible.
- Open it while traveling and confirm only journey information appears.
- Wait about 66 seconds; confirm it moves to **Arrived** without relaunching.
- Open it and verify the exact message and sender.
- Quit and relaunch; confirm the letter is still present.
- Tap **Reset demo** and confirm all mail disappears.

## Edge cases

- Send multiple letters before switching users.
- Send text with leading/trailing spaces.
- Switch users while a letter detail screen is open.
- Relaunch while a letter is traveling and after it should have arrived.
- Test Light Mode, Dark Mode, and the largest accessibility text size.
- Confirm all visible app copy follows the lowercase visual style.
- Confirm muted cards and text remain legible in both Light and Dark Mode.
- Turn on VoiceOver and verify mailbox rows describe the sender and state.
- Test on a small iPhone simulator and a current large iPhone simulator.
- Install on a physical iPhone, accept the trust prompt if shown, and verify launch.

## Known MVP limits

- Two hard-coded local demo correspondents only.
- Firebase identity is live, but letters are still stored locally.
- No friend search, cross-device delivery, or push notifications yet.
- Debug builds accelerate delivery; Release builds use real 24-hour days.
- Message secrecy is a UI simulation until delivery moves to a server.

## Backend security checks

- Unauthenticated callers cannot send or open letters.
- Only accepted friends can send letters to each other.
- Neither sender nor recipient can read `sealedLetters` directly.
- The sender cannot call `openLetter` on a sent letter.
- The recipient cannot open a letter before the server-side `arrivesAt` value.
- Changing device time does not affect server delivery.
- Letter bodies longer than 500 characters are rejected by the server.
