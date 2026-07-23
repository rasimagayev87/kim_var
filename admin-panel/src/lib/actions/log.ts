import "server-only";

import { getAdminDb } from "@/lib/firebase/admin";
import type { AdminSession } from "@/lib/auth/session";
import type { ModerationAction, ModerationTargetType } from "@/lib/data/moderation-logs";

/**
 * Every mutating Server Action in this module calls this right after
 * its write succeeds — the audit trail ("Moderator logları: kim nə
 * edib") is not a bolt-on report generated from other data, it's a
 * direct record of the actor/action/target at the moment it happened.
 * Best-effort: a logging failure must never undo or block the actual
 * moderation action, so this swallows its own errors rather than
 * throwing back into the caller.
 */
export async function logModerationAction({
  actor,
  action,
  targetType,
  targetId,
  note,
}: {
  actor: AdminSession;
  action: ModerationAction;
  targetType: ModerationTargetType;
  targetId: string;
  note?: string;
}): Promise<void> {
  try {
    await getAdminDb().collection("moderationLogs").add({
      actorUid: actor.uid,
      actorEmail: actor.email,
      actorRole: actor.role,
      action,
      targetType,
      targetId,
      ...(note ? { note } : {}),
      createdAt: new Date(),
    });
  } catch {
    // Swallowed — see doc comment above.
  }
}
