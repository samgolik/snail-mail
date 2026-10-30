# MVP QA Pass

For simulator QA, start the complete local backend from the repository root:

```sh
./run-backend.sh
```

Keep it running while testing. Debug simulator builds use the local Auth and
Functions emulators and permit local HTTP traffic; Release and device builds use
production and remain HTTPS-only.

Launch with `./run-simulator.sh`; its preflight must report all backend ports
ready and confirm the generated Debug app’s local-network permission before
installation.

## Happy path

- Launch on a fresh simulator and confirm the sign-up screen appears before the mailbox.
- Confirm the home screen uses the snail-and-envelope icon without white corners.
- Create an account with a new email and a password of at least six characters.
- Confirm the verification email arrives and **You** can resend it.
- Relaunch and confirm the saved email remains signed in.
- Sign out and confirm the app returns to the sign-up/sign-in screen.
- Sign back in and confirm the mailbox opens.
- On **Sign in**, request a password reset and confirm the email arrives.
- Create two accounts on separate simulators and verify both email addresses.
- Exchange a friend code and accept the request from the recipient account.
- Edit the display name, username, and city; relaunch and confirm the new return
  address appears on both devices without changing the friend code.
- Confirm both mailbox sections are initially empty.
- Write a letter to the connected friend and verify blank messages cannot be sent.
- Confirm the counter prevents messages longer than 500 characters.
- Send, open the recipient account, and refresh **Mailbox**.
- Confirm the letter is under **Traveling** and its body is not visible.
- Open it while traveling and confirm only journey information appears.
- Confirm it moves to **Arrived** when server time reaches the arrival date.
- Open it and verify the exact message and sender.
- Quit and relaunch; confirm the letter is still present.
- Delete a disposable account and confirm it cannot sign in again.
- Report a disposable friend and confirm the action completes without exposing the reporter.
- Report a received letter from its overflow menu and confirm the success notice.
- Block a disposable friend and confirm the connection disappears for both sending paths.
- Confirm the blocked account appears privately under **you**, unblock it, exchange
  a new request, then remove the connection without blocking either account.

## Edge cases

- Try malformed emails, a password shorter than six characters, an existing
  email, and an incorrect password; confirm each error is understandable.
- Switch between **Sign up** and **Sign in** and confirm the password is cleared.
- Disable networking, attempt sign-in, restore networking, and retry.
- Disable networking before launch with an existing session; confirm the app
  shows the post-office retry screen rather than profile setup. Restore networking
  and confirm retry reaches the existing mailbox.
- Relaunch with an existing session and confirm there is no flash of the login screen.
- Send multiple letters before switching users.
- Send text with leading/trailing spaces.
- Switch users while a letter detail screen is open.
- Relaunch while a letter is traveling and after it should have arrived.
- Test Light Mode, Dark Mode, and the largest accessibility text size.
- Confirm all visible app copy follows the lowercase visual style.
- Confirm muted cards and text remain legible in both Light and Dark Mode.
- Turn on VoiceOver and verify mailbox rows describe the sender and state.
- Turn on Reduce Motion and confirm auth/root transitions do not animate.
- Test on a small iPhone simulator and a current large iPhone simulator.
- Install on a physical iPhone, accept the trust prompt if shown, and verify launch.
- Archive a Release build and confirm validation finds a 1024×1024 app icon.

## Known MVP limits

- Friend discovery intentionally uses private codes rather than public search.
- Push notifications are not yet enabled; refresh fetches new mail.
- The server caps fictional journeys at 30 days.

## Backend security checks

- Unauthenticated callers cannot send or open letters.
- Production callers without a valid Firebase App Check token are rejected before
  user authorization; the emulator bypass is limited to `FUNCTIONS_EMULATOR=true`.
- Only accepted friends can send letters to each other.
- Neither sender nor recipient can read `sealedLetters` directly.
- A block in either direction prevents new friend requests and letters.
- Only the blocker can see and remove their block; unblocking does not silently
  restore the old friendship.
- The sender cannot call `openLetter` on a sent letter.
- The recipient cannot open a letter before the server-side `arrivesAt` value.
- Changing device time does not affect server delivery.
- Letter bodies longer than 500 characters are rejected by the server.
- Authenticated write-action limits reject abusive profile edits, friend requests,
  letters, and reports without weakening authorization.

The repeatable emulator test is `firebase/functions/test/integration.mjs`.
It passed the complete two-account social flow on October 29, 2026.
