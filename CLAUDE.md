# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository overview

This repo contains three separate deployables that share one Firebase project (`kim-var-73ce9`):

1. **Flutter app** (repo root, package name `kim_var`, product-branded "Meevima", bundle id `com.meevima.app`) — the consumer mobile app (Android/iOS, plus generated desktop/web scaffolding that isn't actively used).
2. **`functions/`** — Firebase Cloud Functions (TypeScript, 2nd gen), the only server-side code the mobile app talks to.
3. **`admin-panel/`** — a Next.js 16 admin/moderation dashboard, deployed via Firebase App Hosting, talking to the same Firestore/Auth project via `firebase-admin`.

`firestore.rules` is the actual authorization boundary for the mobile app and is a primary source of truth for what the client is and isn't allowed to do — read it before assuming a Firestore write path exists.

## Commands

### Flutter app (repo root)
```
flutter pub get                        # install deps
flutter run                            # run on a connected device/emulator
flutter analyze                        # static analysis (flutter_lints)
flutter test                           # run all tests
flutter test test/widget_test.dart     # run a single test file
dart run build_runner build --delete-conflicting-outputs   # regenerate freezed/json_serializable code after editing an entity
flutter gen-l10n                       # regenerate lib/l10n/app_localizations.dart after editing an .arb file (also runs automatically on build since pubspec.yaml sets `generate: true`)
```
Localization source files are `lib/l10n/app_{az,en,ru,tr}.arb`; there is no `l10n.yaml`, so gen-l10n uses Flutter's default conventions (template `app_en.arb`, output into `lib/l10n/`).

### Cloud Functions (`functions/`)
```
cd functions
npm run build         # tsc
npm run build:watch   # tsc --watch
npm run serve         # build + firebase emulators:start --only functions
npm run deploy        # firebase deploy --only functions
npm run logs          # firebase functions:log
```

### Admin panel (`admin-panel/`)
```
cd admin-panel
npm run dev                                     # next dev
npm run build                                   # next build
npm run lint                                    # eslint
npm run bootstrap-admin                         # tsx --env-file=.env.local scripts/bootstrap-admin.ts (grants the first admin custom claim)
```
`admin-panel/AGENTS.md` (auto-loaded there) flags that this is a very recent Next.js major version with breaking API changes — check `node_modules/next/dist/docs/` before writing routing/middleware code instead of relying on prior Next.js knowledge. Notably, `middleware.ts` was renamed to `proxy.ts` and Proxy now runs on the Node.js runtime by default (see `admin-panel/src/proxy.ts`), which is why it can call the Admin SDK directly for session verification.

### Firebase (repo root)
```
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
firebase deploy --only storage
```
`firebase.json` wires `firestore.rules`, `firestore.indexes.json`, `storage.rules`, and `functions/` together under project alias `default` → `kim-var-73ce9` (`.firebaserc`).

## Architecture — Flutter app

Feature-first Clean Architecture under `lib/features/<feature>/`, each split into:
- `domain/` — plain entities and abstract repository interfaces (no Firebase imports).
- `data/repositories/` — concrete `Firebase*Repository` implementations of those interfaces.
- `presentation/providers/` — Riverpod (`flutter_riverpod`) providers/`StateNotifier`s that features consume; screens/widgets live in `presentation/screens|widgets`.

`lib/core/` holds cross-feature building blocks: `theme/` (colors, `ThemeData`), `animations/`, `widgets/` (shared premium UI components), `utils/`, and `data/` (static reference data like countries/cities).

Firebase is the entire backend — `cloud_firestore`, `firebase_auth`, `firebase_storage`, `cloud_functions`, `firebase_messaging`, `firebase_app_check`. There is no custom backend server; anything that needs to run with elevated trust (deleting an account end-to-end, marking phone verification, fan-out push notifications, denormalized counters) is a Cloud Function in `functions/src/index.ts`, invoked from the client via `cloud_functions` `onCall`, or triggered by Firestore document changes.

Sign-in is phone-primary (`startPhoneVerification`/`confirmPhoneCode`) plus Google and Apple (iOS-only) — see `lib/features/auth/domain/repositories/auth_repository.dart`. There is deliberately no email/password sign-in; email is only an optional profile field. Note the auth repository is mid-migration: `firebase_auth_repository.dart` currently also contains an older username/password-backed implementation (synthetic `@users.meevima.app` email addresses via a `usernames` reservation collection) that doesn't match the `AuthRepository` interface's phone/Google/Apple method signatures — check which shape is actually current before building on it.

App Check (`FirebaseAppCheck`) gates SMS/reCAPTCHA and other abuse-prone Firebase APIs — Play Integrity/App Attest in release, the debug provider (allow-listed per-device in the Firebase console) in debug builds.

**Field-level authorization**: several `users/{uid}` fields (`isVerified`, `phoneNumber`, `premium`, `identityVerified`) are grant-of-privilege and are blocked by `firestore.rules` from ever being set by a direct client write, even to their own default value. They are only ever written by Cloud Functions using the Admin SDK (e.g. `markPhoneVerified`). When adding a new privileged flag, follow this same pattern: deny it in `firestore.rules`, set it only from `functions/src/index.ts`.

**Denormalized counters** (`posts.likesCount`/`commentsCount`, `posts/{id}/comments/{id}.likesCount`) are written only by Firestore-triggered Cloud Functions reacting to the underlying `likes`/`comments` subcollections — never incremented directly by the client, and `firestore.rules` enforces that.

## Architecture — Cloud Functions (`functions/src/index.ts`)

Single-file 2nd-gen Functions module (region `us-central1`), three shapes:
- **`onCall` callables** the client invokes directly for privileged operations: `deleteAccount` (full account teardown — chat messages replaced with a placeholder rather than deleted so the other participant's history survives, events archived/left, follows/block-list entries cleaned up, storage prefixes removed, then the Auth user itself deleted) and `markPhoneVerified` (the only path that can set `isVerified`/`phoneNumber`, trusting Firebase Auth's own verified phone claim).
- **Firestore triggers** (`onDocumentCreated/Updated/Deleted`) that maintain denormalized counters (`bumpPostCounter`, `bumpCommentCounter`) and cascade-delete subcollections Firestore doesn't clean up itself (post likes/comments, story views).
- **Notification fan-out** via a shared `notifyUser` helper: writes a `users/{uid}/notifications` doc and sends an FCM push, gated per-category by `users/{uid}.notificationPreferences` (follows, likes, comments, venue updates, chat messages). Never throws — a failed push must never fail the triggering write.

## Architecture — Admin panel (`admin-panel/`)

Next.js App Router, server-first: `src/app/(protected)/*` are the authenticated screens (dashboard, users, venues, offers, feedback/reports, admins, logs, notifications broadcast); data fetching lives in `src/lib/data/*`, mutations in `src/lib/actions/*` (Server Actions), both using `firebase-admin` (`src/lib/firebase/admin.ts`), never the client SDK, so they bypass `firestore.rules` entirely and are the actual trust boundary.

Two roles only (`src/lib/auth/permissions.ts`): `admin` (full access, including managing other admins) and `moderator` (content moderation — venues/offers/feedback — but not users, broadcasts, or the admin roster). Role comes from a Firebase Auth custom claim, never from Firestore data directly — the `admins` Firestore collection is just a denormalized read index for the UI and is not the source of truth.

Session model: `src/lib/auth/session.ts` verifies a freshly-signed-in ID token, checks it already carries a `role` custom claim, and mints a short-lived (5 day) session cookie (`__session`). `src/proxy.ts` does a cheap unrevoked-check redirect gate on every request; anything actually sensitive re-verifies the session itself server-side rather than trusting Proxy coverage alone.

## Localization

Flutter UI strings live in `lib/l10n/app_{az,en,ru,tr}.arb` (Azerbaijani appears to be the primary/default locale based on in-app copy). User-facing error messages and Cloud Functions error strings (`functions/src/index.ts`) are also written in Azerbaijani — match that when adding new ones rather than defaulting to English.
