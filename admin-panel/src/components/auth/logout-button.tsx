"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";

import { Button } from "@/components/ui/button";
import { getFirebaseAuth } from "@/lib/firebase/client";

export function LogoutButton() {
  const router = useRouter();
  const [loading, setLoading] = useState(false);

  async function handleLogout() {
    if (loading) return;
    setLoading(true);
    try {
      await fetch("/api/auth/session", { method: "DELETE" });
    } finally {
      // Best-effort regardless of whether the DELETE above succeeded —
      // a logout button that gets stuck because of a network blip is
      // worse than one that clears local state anyway.
      await getFirebaseAuth().signOut().catch(() => {});
      router.push("/login");
      router.refresh();
    }
  }

  return (
    <Button variant="outline" onClick={handleLogout} disabled={loading} className="w-full">
      {loading ? "Çıxılır..." : "Çıxış et"}
    </Button>
  );
}
