# Kim Var — Admin Panel

Standalone Next.js web dashboard for the Kim Var mobile app. Separate
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
4. Visit `/api/health` to confirm the Admin SDK can reach the project
   (returns `{ ok: true, sampleUserCount: ... }` once credentials are
   correct).

## Notes

- Never commit `.env.local` — it holds the service-account private key.
- `src/lib/firebase/admin.ts` is guarded with `import "server-only"`;
  importing it from a Client Component fails the build on purpose.

## Deploy (Firebase App Hosting)

One-time setup — all of this happens in the Firebase console/CLI under
your own account, not something that can be scripted end-to-end since
step 2 is a GitHub OAuth grant:

1. **Register a Web app** (if not done already, for step 4's client
   config): Firebase console → Project settings → General → Your apps
   → Add app → Web.
2. **Connect the GitHub repo**: Firebase console → Build → App Hosting
   → Get started → connect `rasimagayev87/kim_var`, authorize
   Firebase's GitHub App when prompted.
3. **Create the backend**, pointing at the `admin-panel/` subdirectory:
   ```
   firebase apphosting:backends:create --project kim-var-73ce9 --backend kim-var-admin --root-dir admin-panel --primary-region us-central1
   ```
4. **Fill in the public client values** in `apphosting.yaml`
   (`NEXT_PUBLIC_FIREBASE_API_KEY`, `NEXT_PUBLIC_FIREBASE_APP_ID`) from
   the Web app created in step 1, then commit/push — App Hosting
   redeploys automatically on push to the connected branch.
5. **No Admin SDK secrets to configure** — `lib/firebase/admin.ts`
   uses the backend's own Application Default Credentials
   automatically once deployed (see that file's comments). If a Server
   Action fails after deploy with a permission error, grant the
   backend's service account the "Firebase Authentication Admin" and
   "Cloud Datastore User" IAM roles in Google Cloud Console.

After the first successful rollout, every push to the connected branch
redeploys — no further manual `firebase deploy` needed.
