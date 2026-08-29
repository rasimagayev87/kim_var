import { readFileSync } from "node:fs";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
} from "@firebase/rules-unit-testing";

export const PROJECT_ID = "demo-peakpin-rules-test";

/** One fresh `RulesTestEnvironment` per test FILE (Node's test runner
 * isolates each file into its own process, so a module-level singleton
 * wouldn't be shared across files anyway — each file calls this once in
 * a top-level `before` and `cleanup()`s it in `after`). */
export async function createTestEnv(): Promise<RulesTestEnvironment> {
  return initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: readFileSync("../../firestore.rules", "utf8"),
      host: "127.0.0.1",
      port: 8080,
    },
    storage: {
      rules: readFileSync("../../storage.rules", "utf8"),
      host: "127.0.0.1",
      port: 9199,
    },
  });
}

/** A minimally-complete `users/{uid}` doc — enough to satisfy every
 * `exists(users/{uid})`-style check in firestore.rules (`isActiveUser`,
 * `isBusinessUser`, etc.) without tripping any of the locked-field or
 * size-cap validators. Callers override only what their test cares
 * about. */
export function userFixture(uid: string, overrides: Record<string, unknown> = {}) {
  return {
    uid,
    username: `user_${uid}`,
    accountPrivacy: "public",
    businessStatus: "active",
    bio: "",
    createdAt: new Date(),
    ...overrides,
  };
}

export function venueFixture(ownerId: string, overrides: Record<string, unknown> = {}) {
  return {
    ownerId,
    name: "Test Venue",
    category: "restaurant",
    status: "approved",
    ...overrides,
  };
}
