import assert from "node:assert/strict";

const project = process.env.GCLOUD_PROJECT || "demo-snail-mail";
const authBase = process.env.FIREBASE_AUTH_EMULATOR_HOST || "127.0.0.1:9099";
const functionsBase = process.env.FUNCTIONS_EMULATOR_HOST || "127.0.0.1:5001";
const password = "deliberate-snail-42";

async function json(url, options = {}) {
  const response = await fetch(url, {
    ...options,
    headers: {"content-type": "application/json", ...options.headers},
  });
  const body = await response.json();
  return {response, body};
}

async function createVerifiedUser(label) {
  const email = `${label}-${Date.now()}@example.com`;
  const signup = await json(
    `http://${authBase}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake`,
    {method: "POST", body: JSON.stringify({email, password, returnSecureToken: true})},
  );
  assert.equal(signup.response.ok, true, JSON.stringify(signup.body));
  const localId = signup.body.localId;
  const verificationEmail = await json(
    `http://${authBase}/identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=fake`,
    {
      method: "POST",
      body: JSON.stringify({requestType: "VERIFY_EMAIL", idToken: signup.body.idToken}),
    },
  );
  assert.equal(verificationEmail.response.ok, true, JSON.stringify(verificationEmail.body));
  const codes = await json(
    `http://${authBase}/emulator/v1/projects/${project}/oobCodes`,
  );
  const code = codes.body.oobCodes.find((item) => item.email === email);
  assert.ok(code?.oobCode, "verification code should be generated");
  const verification = await json(
    `http://${authBase}/identitytoolkit.googleapis.com/v1/accounts:update?key=fake`,
    {method: "POST", body: JSON.stringify({oobCode: code.oobCode})},
  );
  assert.equal(verification.response.ok, true, JSON.stringify(verification.body));
  const signin = await json(
    `http://${authBase}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake`,
    {method: "POST", body: JSON.stringify({email, password, returnSecureToken: true})},
  );
  assert.equal(signin.response.ok, true, JSON.stringify(signin.body));
  return {id: localId, token: signin.body.idToken};
}

async function call(name, token, data, expectedStatus = 200) {
  const result = await json(
    `http://${functionsBase}/${project}/us-east1/${name}`,
    {
      method: "POST",
      headers: {authorization: `Bearer ${token}`},
      body: JSON.stringify({data}),
    },
  );
  assert.equal(result.response.status, expectedStatus, `${name}: ${JSON.stringify(result.body)}`);
  return result.body.result ?? result.body.error;
}

const sam = await createVerifiedUser("sam");
const justin = await createVerifiedUser("justin");
await call("saveProfile", sam.token, {
  displayName: "Sam", username: `sam_${Date.now()}`, city: "Washington, DC",
  latitude: 38.9072, longitude: -77.0369,
});
const justinProfile = await call("saveProfile", justin.token, {
  displayName: "Justin", username: `justin_${Date.now()}`, city: "Columbus, OH",
  latitude: 39.9612, longitude: -82.9988,
});
await call("requestFriend", sam.token, {friendCode: justinProfile.profile.friendCode});
const pendingHome = await call("loadHome", justin.token, {});
const incoming = pendingHome.connections.find((item) => item.isIncoming);
assert.ok(incoming, "recipient should receive a friend request");
await call("respondToFriend", justin.token, {friendshipID: incoming.id, accept: true});
await call("sendLetter", sam.token, {
  recipientID: justin.id, body: "This body must stay sealed.",
});
const mailbox = await call("loadHome", justin.token, {});
assert.equal(mailbox.letters.length, 1);
assert.equal("body" in mailbox.letters[0], false, "mailbox metadata leaked a body");
await call("openLetter", justin.token, {letterID: mailbox.letters[0].id}, 400);
await call("reportUser", justin.token, {
  targetID: sam.id, letterID: mailbox.letters[0].id, reason: "integration test report",
});
await call("blockUser", justin.token, {targetID: sam.id});
await call("sendLetter", sam.token, {
  recipientID: justin.id, body: "A blocked letter must not leave.",
}, 403);
for (let index = 0; index < 19; index += 1) {
  await call("saveProfile", sam.token, {
    displayName: "Sam", username: `sam_limit_${index}`,
    city: "Washington, DC", latitude: 38.9072, longitude: -77.0369,
  });
}
await call("saveProfile", sam.token, {
  displayName: "Sam", username: "sam_limit_blocked",
  city: "Washington, DC", latitude: 38.9072, longitude: -77.0369,
}, 429);
await call("deleteAccount", sam.token, {});
await call("deleteAccount", justin.token, {});
console.log("✓ production social flow passed");
