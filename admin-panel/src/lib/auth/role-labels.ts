import type { AdminRole } from "./roles";

/** Human labels for the five roles, in the order they appear in the
 * permission matrix. Kept here (not in `permissions.ts`) so the auth
 * layer stays free of presentation concerns. */
export const ROLE_LABELS: Record<AdminRole, string> = {
  admin: "Admin",
  moderator: "Moderator",
  finance: "Maliyyə",
  support: "Dəstək",
  analyst: "Analitik",
};
