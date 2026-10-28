# MVP QA Pass

## Happy path

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
- Confirm pastel cards and text remain legible in both Light and Dark Mode.
- Turn on VoiceOver and verify mailbox rows describe the sender and state.
- Test on a small iPhone simulator and a current large iPhone simulator.
- Install on a physical iPhone, accept the trust prompt if shown, and verify launch.

## Known MVP limits

- Two hard-coded local demo users only.
- No account system, server, friend search, or push notifications yet.
- Debug builds accelerate delivery; Release builds use real 24-hour days.
- Message secrecy is a UI simulation until delivery moves to a server.
