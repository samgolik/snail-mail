import {initializeApp} from "firebase-admin/app";
import {
  DocumentData,
  FieldValue,
  getFirestore,
  Timestamp,
  Transaction,
} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";

initializeApp();

const db = getFirestore();
const MAX_BODY_LENGTH = 500;
const MILES_PER_SNAIL_DAY = 15;
const MAX_SNAIL_DAYS = 30;

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

export const sendLetter = onCall({region: "us-east1"}, async (request) => {
  const senderID = request.auth?.uid;
  if (!senderID) {
    throw new HttpsError("unauthenticated", "sign in before sending a letter");
  }

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
  const userID = request.auth?.uid;
  if (!userID) {
    throw new HttpsError("unauthenticated", "sign in before opening a letter");
  }
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
