import { getApp, getApps, initializeApp, type FirebaseApp, type FirebaseOptions } from "firebase/app";
import { getAuth, type Auth } from "firebase/auth";

// Public config — safe to ship to the browser (Firebase's own security
// model is enforced by custom claims + firestore.rules, not by hiding
// these values). Only used by the admin login page; every other read/
// write in this app goes through the server-side Admin SDK instead
// (see lib/firebase/admin.ts), which is the actual trust boundary.
const firebaseConfig: FirebaseOptions = {
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
  authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN,
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
  storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID,
};

// Lazy, not a module-top-level `const` — this module gets IMPORTED
// (though never actually invoked) on the server too, whenever a
// Server Component references a "use client" component that uses it
// (Next needs to load the module to build the RSC payload). Firebase
// Auth's `getAuth()` validates its config eagerly and throws on a
// missing/invalid API key, so an eager top-level call here would crash
// every server render of /login or /dashboard until real
// NEXT_PUBLIC_FIREBASE_* values exist — not just break in the browser.
// Wrapping it in a function means the body only runs when something
// (a click handler, always client-side) actually calls it.
let cachedApp: FirebaseApp | undefined;
let cachedAuth: Auth | undefined;

function getFirebaseApp(): FirebaseApp {
  return (cachedApp ??= getApps().length ? getApp() : initializeApp(firebaseConfig));
}

export function getFirebaseAuth(): Auth {
  return (cachedAuth ??= getAuth(getFirebaseApp()));
}
