# MVP QA Pass

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
- Block a disposable friend and confirm the connection disappears for both sending paths.

## Edge cases

- Try malformed emails, a password shorter than six characters, an existing
  email, and an incorrect password; confirm each error is understandable.
- Switch between **Sign up** and **Sign in** and confirm the password is cleared.
- Disable networking, attempt sign-in, restore networking, and retry.
- Relaunch with an existing session and confirm there is no flash of the login screen.
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
- Archive a Release build and confirm validation finds a 1024×1024 app icon.

## Known MVP limits

- Friend discovery intentionally uses private codes rather than public search.
- Push notifications are not yet enabled; refresh fetches new mail.
- The server caps fictional journeys at 30 days.

## Backend security checks

- Unauthenticated callers cannot send or open letters.
- Only accepted friends can send letters to each other.
- Neither sender nor recipient can read `sealedLetters` directly.
- A block in either direction prevents new friend requests and letters.
- The sender cannot call `openLetter` on a sent letter.
- The recipient cannot open a letter before the server-side `arrivesAt` value.
- Changing device time does not affect server delivery.
- Letter bodies longer than 500 characters are rejected by the server.
