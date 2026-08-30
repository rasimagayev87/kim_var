# PeakPin — Admin Panel

Standalone Next.js web dashboard for the PeakPin mobile app. Separate
codebase, same Firebase project (`kim-var-73ce9`) — Firestore, Auth,
and Storage are shared with the Flutter app in the parent directory.

## Stack

- Next.js 16 (App Router) + TypeScript
- Tailwind CSS v4 + shadcn/ui
- Firebase Admin SDK — every real data read/write (server-only, full
  trust, bypasses `firestore.rules`)
- Firebase Client SDK — login page only (`signInWithEmailAndPassword`)

## Setup

1. `npm install`
2. Copy `.env.local.example` to `.env.local` and fill in the values:
   - **Client config**: Firebase console → Project settings → General
     → Your apps. If no "Web app" exists yet for this project, add one
     there first (Android/iOS apps don't provide a browser API key).
   - **Admin config**: Firebase console → Project settings → Service
     accounts → Generate new private key. Copy `project_id`,
     `client_email`, and `private_key` out of the downloaded JSON.
3. `npm run dev` — starts at http://localhost:3000
4. Sign in at `/login` with an admin account to confirm the Admin SDK
   can reach the project — the dashboard's counters come straight
   through it, so a working dashboard is the same proof the old
   `/api/health` route gave.

   > That route was **removed** (P0 / H-8). It called
   > `getAdminAuth().listUsers(1)` with no authentication whatsoever,
   > and Proxy's matcher excludes `/api` — so anyone on the internet
   > could confirm the panel's existence, read back `projectId`, get the
   > raw Firebase error text on failure, and make the backend issue
   > Firebase Auth Admin API calls on demand. Its own comment called it
   > a temporary Phase 1 check "to be deleted once a real dashboard is
   > live"; the dashboard has been live for a long time.

## Notes

- Never commit `.env.local` — it holds the service-account private key.
- `src/lib/firebase/admin.ts` is guarded with `import "server-only"`;
  importing it from a Client Component fails the build on purpose.

## Deploy (Vercel)

**Production is `admin.peakpin.app`, hosted on Vercel.** Deploys are
made from a developer machine with the Vercel CLI; there is no
git-triggered build, so pushing to GitHub does NOT deploy this panel.

```
cd admin-panel
vercel --prod
```

The project link lives in `admin-panel/.vercel/project.json`
(`peakpin/admin-panel`). Root Directory is `admin-panel/` itself, so the
command must be run from this directory.

Environment variables are configured in the Vercel dashboard
(Project → Settings → Environment Variables), Production scope. All
nine are required and already set:

* `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY`
  — the Admin SDK service account. Unlike a Google-hosted runtime,
  Vercel provides no Application Default Credentials, so
  `lib/firebase/admin.ts` takes its explicit-credentials branch. These
  are real secrets; they exist only in the Vercel dashboard and in
  local `.env.local`, never in the repo.
* `NEXT_PUBLIC_FIREBASE_*` (six) — the browser client config.

### Firebase App Hosting is NOT used

A Firebase App Hosting backend named `kim-var-admin` exists on the
project and answers at
`kim-var-admin--kim-var-73ce9.us-central1.hosted.app`. **It is not
production and nothing routes to it.** Its last rollout was 4 August
2026; `admin.peakpin.app` has never pointed at it.

This has already caused one real incident: a deploy verification was
run against the App Hosting URL, saw the expected result, and reported
a security fix as live when production was still serving the old build.
If you are verifying a deploy, curl `admin.peakpin.app` — not the
`hosted.app` URL.

`apphosting.yaml` is kept only because deleting it is a separate
decision from this one; it configures the unused backend and is not
read by Vercel.
