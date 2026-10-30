# App Store submission record

## Listing

- Name: **snail mail**
- Subtitle: **messages worth waiting for**
- Primary category: **Social Networking**
- Secondary category: **Lifestyle**
- Bundle ID: `com.samgolik.snailmail`
- Support URL: `https://snail-mail-btc.web.app/support`
- Privacy URL: `https://snail-mail-btc.web.app/privacy`
- Marketing URL: `https://snail-mail-btc.web.app`
- Terms URL: `https://snail-mail-btc.web.app/terms`
- Community Guidelines: `https://snail-mail-btc.web.app/community`

## Promotional text

Some messages deserve a journey. Write a letter, seal it, and let a tiny
fictional snail carry it to a friend.

## Description

snail mail is a slower social app for messages worth waiting for.

Exchange a private friend code, write a letter, and watch it travel between your
cities at a fictional snail’s pace. The contents stay sealed until the
server-calculated arrival time—no peeking and no rushing the road.

- private friend-code connections
- cross-device delayed letters
- sealed contents until arrival
- in-app reporting, reversible blocking, connection removal, and permanent account deletion
- a calm mailbox without feeds, likes, or read-pressure

Made thoughtfully by beat the clock studios.

## Keywords

`letters,mail,friends,delayed,messaging,penpal,slow,private`

## App Privacy answers

Data is linked to the user and used for **App Functionality**:

- Contact Info → Email Address
- User Content → Other User Content (letter bodies)
- Identifiers → User ID
- Location → Coarse Location (city-derived coordinates)
- Other Data → profile name, username, city, friend relationships, blocks,
  safety reports, terms-acceptance records, delivery metadata, and App Attest
  security proofs

Firebase App Check processes an App Attest attestation object and assertion object
to prevent abuse. In Apple’s current questionnaire, disclose this under the
closest security/fraud-prevention purpose and re-check whether **Other Data** or a
device-identifier category is requested by the live form.

Select **No** for tracking. Select **No** for third-party advertising and
developer advertising. Review Firebase’s current SDK disclosures again at
submission time in case Apple’s taxonomy or Firebase behavior has changed.

## Review notes

Two verified accounts and an accepted friendship are needed to exercise the
full flow. Provide App Review with dedicated credentials for both accounts and
their friend codes. Explain that delivery is intentionally delayed and supply a
server-created letter that has already arrived so Review can test opening
without waiting.

Report and block controls appear in the received-letter overflow menu and under
**you → friends**. Permanent deletion appears under **you → account**. A network
failure at launch shows a retry screen and never creates or overwrites a profile.
Every account must accept the current Terms of Use and Community Guidelines
before connecting with friends or sending letters; acceptance is versioned and
recorded server-side.

## Age rating and policy selections

- Use Apple’s current questionnaire and answer from the shipped build, not this
  draft. The app contains user-generated private messages and account-to-account
  communication, with reporting and blocking controls.
- There is no public feed, web browsing, gambling, advertising, or in-app purchase.
- The product is not designed for children under 13; do not select the Kids category.
- Use Apple’s standard EULA unless beat the clock studios supplies a reviewed
  custom agreement.
- Confirm the developer name, support contact, copyright owner, and content-rights
  declaration in App Store Connect before submission.

## Export compliance

The target sets `ITSAppUsesNonExemptEncryption` to `NO`. The app uses ordinary
system/Firebase HTTPS and authentication encryption and does not implement its
own non-exempt cryptography. Re-evaluate this answer if cryptographic behavior or
Apple’s questionnaire changes.

## Screenshot set

Capture on the current required iPhone display sizes:

1. welcome/sign-up — “messages worth waiting for”
2. return-address setup
3. mailbox with one traveling letter
4. sealed journey detail
5. arrived letter after opening
6. friend-code address book

Do not include simulator chrome, personal email addresses, or placeholder/demo
copy. Use the same two fictional review accounts throughout the set.
