import {
  ClipboardList,
  Flag,
  LayoutDashboard,
  Megaphone,
  ShieldCheck,
  Store,
  Tag,
  Users,
  type LucideIcon,
} from "lucide-react";

import type { Permission } from "@/lib/auth/permissions";

export interface NavItem {
  label: string;
  href: string;
  icon: LucideIcon;
  /** Omitted = every role with a session can see it (Dashboard, Loglar). */
  permission?: Permission;
  /**
   * True until that module's phase actually builds the route — shown
   * disabled with a "tezliklə" badge instead of linking to a 404, same
   * "don't ship a dead end" reasoning as the mobile app's
   * ComingSoonScreen.
   */
  comingSoon?: boolean;
}

export const NAV_ITEMS: NavItem[] = [
  { label: "Dashboard", href: "/dashboard", icon: LayoutDashboard },
  { label: "İstifadəçilər", href: "/users", icon: Users, permission: "manageUsers" },
  { label: "Məkanlar", href: "/venues", icon: Store, permission: "moderateVenues" },
  { label: "Təkliflər", href: "/offers", icon: Tag, permission: "moderateOffers" },
  { label: "Şikayətlər", href: "/feedback", icon: Flag, permission: "manageFeedback" },
  { label: "Bildirişlər", href: "/notifications", icon: Megaphone, permission: "broadcastNotifications" },
  { label: "Loglar", href: "/logs", icon: ClipboardList },
  { label: "Admin idarəetməsi", href: "/admins", icon: ShieldCheck, permission: "manageAdmins" },
];
