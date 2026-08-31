import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { ADMIN_ROLES, type AdminRole } from "@/lib/auth/roles";
import { ROLE_LABELS } from "@/lib/auth/role-labels";
import { PERMISSIONS_BY_ROLE, UNIMPLEMENTED_PERMISSIONS, type Permission } from "@/lib/auth/permissions";

/** Az labels for each permission, and which group it belongs to. */
const PERMISSION_LABELS: Record<Permission, string> = {
  viewDashboard: "İdarə paneli",
  viewUsers: "İstifadəçilər",
  viewVenues: "Məkanlar",
  viewOffers: "Təkliflər",
  viewPinBoxes: "PinBox",
  viewEvents: "Tədbirlər",
  viewSubscriptions: "Abunəliklər",
  viewBoosts: "Boostlar",
  viewPayments: "Ödənişlər",
  viewFinancials: "Maliyyə hesabatları",
  viewEpointTransactions: "Epoint əməliyyatları",
  viewSupportMessages: "Dəstək müraciətləri",
  viewBroadcasts: "Kütləvi bildiriş ekranı",
  viewAnalytics: "Analitika",
  viewEngagementMetrics: "DAU / WAU / MAU",
  viewRevenue: "Gəlir analitikası",
  viewAuditLogs: "Audit logları",
  viewAdminNotifications: "Bildiriş zəngi",
  manageUsers: "İstifadəçi redaktəsi",
  banUsers: "İstifadəçi ban",
  deleteUsers: "Hesab silmə",
  moderateVenues: "Məkan moderasiyası",
  manageVenues: "Məkan idarəetməsi",
  moderateOffers: "Təklif moderasiyası",
  broadcastNotifications: "Kütləvi bildiriş göndərmə",
  manageFeedback: "Şikayətlər",
  manageAdmins: "Adminlər və rollar",
  moderateIdentityVerifications: "KYC",
  managePayments: "Ödəniş əməliyyatları",
  manageSubscriptions: "Abunə idarəetməsi",
  manageBoosts: "Boost idarəetməsi",
  manageFinancials: "Maliyyə əməliyyatları",
  manageSupportMessages: "Dəstək cavabları",
  manageSystemSettings: "Sistem ayarları",
  exportData: "Export — ümumi",
  exportFinancialData: "Export — maliyyə",
};

const ALL_PERMISSIONS = Object.keys(PERMISSIONS_BY_ROLE.admin) as Permission[];
const VIEW_PERMISSIONS = ALL_PERMISSIONS.filter((p) => p.startsWith("view"));
const ACT_PERMISSIONS = ALL_PERMISSIONS.filter((p) => !p.startsWith("view"));

function Cell({ allowed }: { allowed: boolean }) {
  return (
    <TableCell className="text-center">
      <span
        aria-label={allowed ? "icazə var" : "icazə yoxdur"}
        className={allowed ? "text-emerald-600 dark:text-emerald-400" : "text-muted-foreground/40"}
      >
        {allowed ? "✅" : "—"}
      </span>
    </TableCell>
  );
}

function Section({
  title,
  note,
  permissions,
  currentRole,
}: {
  title: string;
  note: string;
  permissions: Permission[];
  currentRole: AdminRole;
}) {
  return (
    <div className="space-y-2">
      <div>
        <h2 className="text-lg font-medium">{title}</h2>
        <p className="text-sm text-muted-foreground">{note}</p>
      </div>
      <div className="overflow-x-auto rounded-lg border">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead className="min-w-56">İcazə</TableHead>
              {ADMIN_ROLES.map((role) => (
                <TableHead
                  key={role}
                  className={`text-center ${role === currentRole ? "font-semibold text-foreground" : ""}`}
                >
                  {ROLE_LABELS[role]}
                  {role === currentRole ? <span className="block text-xs font-normal">(siz)</span> : null}
                </TableHead>
              ))}
            </TableRow>
          </TableHeader>
          <TableBody>
            {permissions.map((permission) => {
              const unimplemented = UNIMPLEMENTED_PERMISSIONS.includes(permission);
              return (
                <TableRow key={permission}>
                  <TableCell className="text-sm">
                    <span className={unimplemented ? "text-muted-foreground" : ""}>
                      {PERMISSION_LABELS[permission]}
                    </span>
                    {unimplemented ? (
                      <span className="ml-2 rounded border px-1.5 py-0.5 text-[10px] uppercase tracking-wide text-muted-foreground">
                        səhifə yoxdur
                      </span>
                    ) : null}
                    <code className="ml-2 text-[11px] text-muted-foreground/70">{permission}</code>
                  </TableCell>
                  {ADMIN_ROLES.map((role) => (
                    <Cell key={role} allowed={PERMISSIONS_BY_ROLE[role][permission]} />
                  ))}
                </TableRow>
              );
            })}
          </TableBody>
        </Table>
      </div>
    </div>
  );
}

/**
 * Renders `PERMISSION_MATRIX` directly — no copy, no second list. If
 * the matrix changes, this screen changes with it, which is the only
 * way a permissions reference stays true.
 *
 * Read-only by design. Role assignment lives on `/admins`; a matrix
 * editor would mean roles defined at runtime, and every guard in the
 * app is written against a compile-time union.
 */
export function PermissionMatrixTable({ currentRole }: { currentRole: AdminRole }) {
  return (
    <div className="space-y-8">
      <Section
        title="Görmə icazələri"
        note="Səhifənin açılıb-açılmadığını təyin edir. Bir səhifəni görmək orada əməliyyat etmək demək deyil."
        permissions={VIEW_PERMISSIONS}
        currentRole={currentRole}
      />
      <Section
        title="Əməliyyat icazələri"
        note="Data dəyişən hər server action bunlardan birini tələb edir. Sidebar filtri authorization deyil — yoxlama serverdədir."
        permissions={ACT_PERMISSIONS}
        currentRole={currentRole}
      />
    </div>
  );
}
