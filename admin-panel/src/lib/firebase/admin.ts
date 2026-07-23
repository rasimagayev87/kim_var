import "server-only";

import { cert, getApp, getApps, initializeApp, type App } from "firebase-admin/app";
import { getAuth, type Auth } from "firebase-admin/auth";
import { getFirestore, type Firestore } from "firebase-admin/firestore";
import { getStorage, type Storage } from "firebase-admin/storage";

// `import "server-only"` makes any accidental import of this module
// from a Client Component a BUILD error, not just a runtime mistake —
// the whole point of this file is that its credentials must never
// reach the browser bundle. Every admin-panel data read/write and
// every custom-claim change goes through this Admin SDK (full trust,
// bypasses firestore.rules entirely), never the client SDK in
// lib/firebase/client.ts, which exists only for the login page.
//
// Lazily initialized (not at module top-level) so importing this file
// doesn't itself throw when .env.local isn't set up yet — Next.js can
// load/bundle-analyze a route module without ever calling its handler,
// and a top-level throw there would fail `next build`/`next dev`
// entirely instead of just the one request that actually needs
// credentials.
let cachedApp: App | undefined;

const STORAGE_BUCKET = "kim-var-73ce9.firebasestorage.app";

function getAdminApp(): App {
  if (cachedApp) return cachedApp;
  if (getApps().length) {
    cachedApp = getApp();
    return cachedApp;
  }

  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
  // Service-account JSON files store the key with literal `\n` escapes;
  // env files can't hold real newlines in a single-line value, so the
  // console/.env.local convention is to keep them escaped and unescape
  // here.
  const privateKey = process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, "\n");

  if (clientEmail && privateKey) {
    // Local dev — no Application Default Credentials available outside
    // Google's own infrastructure, so an explicit service-account key
    // from .env.local is what makes this work at all.
    const projectId = process.env.FIREBASE_PROJECT_ID;
    if (!projectId) {
      throw new Error(
        "FIREBASE_PROJECT_ID is missing in .env.local (see .env.local.example).",
      );
    }
    cachedApp = initializeApp({
      credential: cert({ projectId, clientEmail, privateKey }),
      storageBucket: STORAGE_BUCKET,
    });
  } else if (process.env.K_SERVICE || process.env.GOOGLE_CLOUD_PROJECT || process.env.GCLOUD_PROJECT) {
    // Deployed on Firebase App Hosting (Cloud Run — `K_SERVICE` is
    // Cloud Run's own always-set env var) — the backend's attached
    // service account provides Application Default Credentials
    // automatically; no key material needs to exist anywhere for this
    // path, which is the more secure option whenever it's available.
    // See apphosting.yaml: FIREBASE_CLIENT_EMAIL/FIREBASE_PRIVATE_KEY
    // are deliberately NOT set there.
    cachedApp = initializeApp({ storageBucket: STORAGE_BUCKET });
  } else {
    // Neither explicit credentials nor a recognizable Google Cloud
    // environment — almost certainly a local machine with no
    // .env.local. Failing fast with a clear message here beats letting
    // the ADC path attempt anyway and surface a cryptic "Unable to
    // detect a Project Id" error instead.
    throw new Error(
      "Firebase Admin SDK credentials are missing — set FIREBASE_PROJECT_ID, " +
        "FIREBASE_CLIENT_EMAIL and FIREBASE_PRIVATE_KEY in .env.local " +
        "(see .env.local.example).",
    );
  }
  return cachedApp;
}

let cachedAuth: Auth | undefined;
let cachedDb: Firestore | undefined;
let cachedStorage: Storage | undefined;

export function getAdminAuth(): Auth {
  return (cachedAuth ??= getAuth(getAdminApp()));
}

export function getAdminDb(): Firestore {
  return (cachedDb ??= getFirestore(getAdminApp()));
}

export function getAdminStorage(): Storage {
  return (cachedStorage ??= getStorage(getAdminApp()));
}
