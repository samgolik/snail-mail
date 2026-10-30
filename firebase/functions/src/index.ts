import {randomBytes} from "node:crypto";
import {initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {
  DocumentData,
  DocumentSnapshot,
  FieldValue,
  getFirestore,
  QueryDocumentSnapshot,
  Timestamp,
  Transaction,
} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";

initializeApp();

const db = getFirestore();
const MAX_BODY_LENGTH = 500;
const MILES_PER_SNAIL_DAY = 15;
const MAX_SNAIL_DAYS = 30;

function requireUser(request: {auth?: {uid: string; token: {[key: string]: unknown}}}): string {
  const id = request.auth?.uid;
  if (!id) throw new HttpsError("unauthenticated", "sign in to continue");
  return id;
}

function requireVerifiedUser(
  request: {auth?: {uid: string; token: {[key: string]: unknown}}},
): string {
  const id = requireUser(request);
  if (request.auth?.token.email_verified !== true) {
    throw new HttpsError("failed-precondition", "verify your email to connect with friends");
  }
  return id;
}

function requireNumber(value: unknown, field: string, min: number, max: number): number {
  if (typeof value !== "number" || !Number.isFinite(value) || value < min || value > max) {
    throw new HttpsError("invalid-argument", `${field} is invalid`);
  }
  return value;
}

type Coordinates = {
  latitude: number;
  longitude: number;
};

function requireText(value: unknown, field: string, maxLength: number): string {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${field} must be text`);
  }
  const clean = value.trim();
  if (clean.length === 0 || clean.length > maxLength) {
    throw new HttpsError(
      "invalid-argument",
      `${field} must contain 1–${maxLength} characters`,
    );
  }
  return clean;
}

function coordinates(data: DocumentData): Coordinates {
  const {latitude, longitude} = data;
  if (
    typeof latitude !== "number" ||
    typeof longitude !== "number" ||
    latitude < -90 || latitude > 90 ||
    longitude < -180 || longitude > 180
  ) {
    throw new HttpsError("failed-precondition", "profile location is invalid");
  }
  return {latitude, longitude};
}

function distanceMiles(origin: Coordinates, destination: Coordinates): number {
  const radians = (degrees: number) => degrees * Math.PI / 180;
  const earthRadiusMiles = 3958.8;
  const latitudeDelta = radians(destination.latitude - origin.latitude);
  const longitudeDelta = radians(destination.longitude - origin.longitude);
  const a =
    Math.sin(latitudeDelta / 2) ** 2 +
    Math.cos(radians(origin.latitude)) *
      Math.cos(radians(destination.latitude)) *
      Math.sin(longitudeDelta / 2) ** 2;
  return earthRadiusMiles * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function profileJSON(id: string, data: DocumentData) {
  return {
    id,
    displayName: data.displayName,
    username: data.username,
    city: data.city,
    latitude: data.latitude,
    longitude: data.longitude,
    friendCode: data.friendCode,
  };
}

function letterJSON(id: string, data: DocumentData) {
  return {
    id,
    senderID: data.senderID,
    recipientID: data.recipientID,
    originCity: data.originCity,
    destinationCity: data.destinationCity,
    distanceMiles: data.distanceMiles,
    snailDays: data.snailDays,
    sentAt: (data.sentAt as Timestamp).toDate().toISOString(),
    arrivesAt: (data.arrivesAt as Timestamp).toDate().toISOString(),
    status: data.status,
  };
}

export const saveProfile = onCall({region: "us-east1"}, async (request) => {
  const id = requireUser(request);
  const displayName = requireText(request.data?.displayName, "displayName", 40);
  const username = requireText(request.data?.username, "username", 24)
    .replace(/^@/, "").toLowerCase();
  if (!/^[a-z0-9_]{3,24}$/.test(username)) {
    throw new HttpsError("invalid-argument", "username must be 3–24 letters, numbers, or underscores");
  }
  const city = requireText(request.data?.city, "city", 80);
  const latitude = requireNumber(request.data?.latitude, "latitude", -90, 90);
  const longitude = requireNumber(request.data?.longitude, "longitude", -180, 180);
  const userRef = db.collection("users").doc(id);
  const initial = await userRef.get();
  const friendCode = initial.data()?.friendCode ??
    randomBytes(5).toString("hex").toUpperCase();

  await db.runTransaction(async (transaction: Transaction) => {
    const current = await transaction.get(userRef);
    const usernameRef = db.collection("usernames").doc(username);
    const codeRef = db.collection("friendCodes").doc(friendCode);
    const [reservedUsername, reservedCode] = await Promise.all([
      transaction.get(usernameRef),
      transaction.get(codeRef),
    ]);
    if (reservedUsername.exists && reservedUsername.data()?.userID !== id) {
      throw new HttpsError("already-exists", "that username is already taken");
    }
    if (reservedCode.exists && reservedCode.data()?.userID !== id) {
      throw new HttpsError("aborted", "please try saving your profile again");
    }
    const oldUsername = current.data()?.usernameNormalized as string | undefined;
    if (oldUsername && oldUsername !== username) {
      transaction.delete(db.collection("usernames").doc(oldUsername));
    }
    transaction.set(usernameRef, {userID: id});
    transaction.set(codeRef, {userID: id});
    transaction.set(userRef, {
      displayName,
      username: `@${username}`,
      usernameNormalized: username,
      city,
      latitude,
      longitude,
      friendCode,
      createdAt: current.data()?.createdAt ?? FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
  return {profile: {id, displayName, username: `@${username}`, city,
    latitude, longitude, friendCode}};
});

export const requestFriend = onCall({region: "us-east1"}, async (request) => {
  const requesterID = requireVerifiedUser(request);
  const code = requireText(request.data?.friendCode, "friendCode", 10).toUpperCase();
  const codeDoc = await db.collection("friendCodes").doc(code).get();
  const recipientID = codeDoc.data()?.userID as string | undefined;
  if (!recipientID) throw new HttpsError("not-found", "friend code not found");
  if (recipientID === requesterID) {
    throw new HttpsError("invalid-argument", "that is your own friend code");
  }
  const friendshipID = [requesterID, recipientID].sort().join("_");
  const ref = db.collection("friendships").doc(friendshipID);
  await db.runTransaction(async (transaction: Transaction) => {
    if ((await transaction.get(ref)).exists) {
      throw new HttpsError("already-exists", "a friend request already exists");
    }
    transaction.create(ref, {
      userIDs: [requesterID, recipientID],
      requestedBy: requesterID,
      status: "pending",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
  return {friendshipID};
});

export const respondToFriend = onCall({region: "us-east1"}, async (request) => {
  const id = requireVerifiedUser(request);
  const friendshipID = requireText(request.data?.friendshipID, "friendshipID", 300);
  if (typeof request.data?.accept !== "boolean") {
    throw new HttpsError("invalid-argument", "accept must be true or false");
  }
  const ref = db.collection("friendships").doc(friendshipID);
  await db.runTransaction(async (transaction: Transaction) => {
    const snapshot = await transaction.get(ref);
    const data = snapshot.data();
    if (!data || !(data.userIDs as string[]).includes(id) ||
        data.requestedBy === id || data.status !== "pending") {
      throw new HttpsError("permission-denied", "this request cannot be changed");
    }
    if (request.data.accept) {
      transaction.update(ref, {status: "accepted", updatedAt: FieldValue.serverTimestamp()});
    } else {
      transaction.delete(ref);
    }
  });
  return {accepted: request.data.accept};
});

export const loadHome = onCall({region: "us-east1"}, async (request) => {
  const id = requireUser(request);
  const [profile, friendships, received, sent] = await Promise.all([
    db.collection("users").doc(id).get(),
    db.collection("friendships").where("userIDs", "array-contains", id).get(),
    db.collection("letters").where("recipientID", "==", id).orderBy("sentAt", "desc").limit(100).get(),
    db.collection("letters").where("senderID", "==", id).orderBy("sentAt", "desc").limit(100).get(),
  ]);
  const otherIDs: string[] = friendships.docs.map((item: QueryDocumentSnapshot) =>
    (item.data().userIDs as string[]).find((value) => value !== id)!);
  const people = await Promise.all(otherIDs.map((otherID: string) =>
    db.collection("users").doc(otherID).get()));
  const peopleByID = new Map(people.filter((item: DocumentSnapshot) => item.exists)
    .map((item: DocumentSnapshot) => [item.id, profileJSON(item.id, item.data()!)]));
  const connections = friendships.docs.map((item: QueryDocumentSnapshot) => {
    const data = item.data();
    const otherID = (data.userIDs as string[]).find((value) => value !== id)!;
    return {
      id: item.id,
      status: data.status,
      isIncoming: data.requestedBy !== id,
      profile: peopleByID.get(otherID),
    };
  }).filter((item: {profile: unknown}) => item.profile);
  const allLetters = [...received.docs, ...sent.docs]
    .filter((item, index, all) => all.findIndex((other) => other.id === item.id) === index);
  return {
    profile: profile.exists ? profileJSON(profile.id, profile.data()!) : null,
    connections,
    letters: allLetters.map((item) => letterJSON(item.id, item.data())),
  };
});

export const sendLetter = onCall({region: "us-east1"}, async (request) => {
  const senderID = requireVerifiedUser(request);

  const recipientID = requireText(request.data?.recipientID, "recipientID", 128);
  const body = requireText(request.data?.body, "body", MAX_BODY_LENGTH);
  if (recipientID === senderID) {
    throw new HttpsError("invalid-argument", "you cannot send a letter to yourself");
  }

  const friendshipID = [senderID, recipientID].sort().join("_");
  const senderRef = db.collection("users").doc(senderID);
  const recipientRef = db.collection("users").doc(recipientID);
  const friendshipRef = db.collection("friendships").doc(friendshipID);
  const letterRef = db.collection("letters").doc();
  const sealedRef = db.collection("sealedLetters").doc(letterRef.id);

  const result = await db.runTransaction(async (transaction: Transaction) => {
    const [sender, recipient, friendship] = await Promise.all([
      transaction.get(senderRef),
      transaction.get(recipientRef),
      transaction.get(friendshipRef),
    ]);
    if (!sender.exists || !recipient.exists) {
      throw new HttpsError("not-found", "sender or recipient profile is missing");
    }
    if (!friendship.exists || friendship.data()?.status !== "accepted") {
      throw new HttpsError("permission-denied", "letters require an accepted friendship");
    }

    const senderData = sender.data()!;
    const recipientData = recipient.data()!;
    const miles = Math.round(distanceMiles(coordinates(senderData), coordinates(recipientData)));
    const snailDays = Math.min(
      Math.max(Math.ceil(miles / MILES_PER_SNAIL_DAY), 1),
      MAX_SNAIL_DAYS,
    );
    const sentAt = Timestamp.now();
    const arrivesAt = Timestamp.fromMillis(sentAt.toMillis() + snailDays * 86_400_000);

    transaction.create(letterRef, {
      senderID,
      recipientID,
      originCity: senderData.city,
      destinationCity: recipientData.city,
      distanceMiles: miles,
      snailDays,
      sentAt,
      arrivesAt,
      status: "traveling",
    });
    transaction.create(sealedRef, {body, createdAt: sentAt});

    return {letterID: letterRef.id, arrivesAt: arrivesAt.toDate().toISOString()};
  });

  return result;
});

export const openLetter = onCall({region: "us-east1"}, async (request) => {
  const userID = requireUser(request);
  const letterID = requireText(request.data?.letterID, "letterID", 128);
  const letterRef = db.collection("letters").doc(letterID);
  const sealedRef = db.collection("sealedLetters").doc(letterID);

  return db.runTransaction(async (transaction: Transaction) => {
    const [letter, sealed] = await Promise.all([
      transaction.get(letterRef),
      transaction.get(sealedRef),
    ]);
    if (!letter.exists || !sealed.exists) {
      throw new HttpsError("not-found", "letter not found");
    }
    const letterData = letter.data()!;
    if (letterData.recipientID !== userID) {
      throw new HttpsError("permission-denied", "only the recipient can open this letter");
    }
    const arrivesAt = letterData.arrivesAt as Timestamp;
    if (Timestamp.now().toMillis() < arrivesAt.toMillis()) {
      throw new HttpsError("failed-precondition", "this letter is still traveling");
    }

    transaction.update(letterRef, {
      status: "arrived",
      openedAt: FieldValue.serverTimestamp(),
    });
    return {body: sealed.data()!.body as string};
  });
});

export const deleteAccount = onCall({region: "us-east1"}, async (request) => {
  const id = requireUser(request);
  const profileRef = db.collection("users").doc(id);
  const profile = await profileRef.get();
  const [friendships, received, sent] = await Promise.all([
    db.collection("friendships").where("userIDs", "array-contains", id).get(),
    db.collection("letters").where("recipientID", "==", id).get(),
    db.collection("letters").where("senderID", "==", id).get(),
  ]);
  const letters = [...received.docs, ...sent.docs]
    .filter((item, index, all) => all.findIndex((other) => other.id === item.id) === index);
  const batch = db.batch();
  friendships.docs.forEach((item: QueryDocumentSnapshot) => batch.delete(item.ref));
  letters.forEach((item) => {
    batch.delete(item.ref);
    batch.delete(db.collection("sealedLetters").doc(item.id));
  });
  const username = profile.data()?.usernameNormalized as string | undefined;
  const friendCode = profile.data()?.friendCode as string | undefined;
  if (username) batch.delete(db.collection("usernames").doc(username));
  if (friendCode) batch.delete(db.collection("friendCodes").doc(friendCode));
  batch.delete(profileRef);
  await batch.commit();
  await getAuth().deleteUser(id);
  return {deleted: true};
});
