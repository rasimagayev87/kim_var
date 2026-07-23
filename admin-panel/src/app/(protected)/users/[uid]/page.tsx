import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { ArrowLeft } from "lucide-react";

import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { UserDetailActions } from "@/components/users/user-detail-actions";
import { UserPostsPanel } from "@/components/content/user-posts-panel";
import { hasPermission } from "@/lib/auth/permissions";
import { getCurrentAdmin } from "@/lib/auth/server";
import { listUserPosts } from "@/lib/data/content";
import { getUserDetail } from "@/lib/data/users";

function formatDate(iso: string | null): string {
  if (!iso) return "Naməlum";
  return new Date(iso).toLocaleDateString("az-AZ", { year: "numeric", month: "long", day: "numeric" });
}

export default async function UserDetailPage({ params }: { params: Promise<{ uid: string }> }) {
  const admin = await getCurrentAdmin();
  if (!admin || !hasPermission(admin.role, "manageUsers")) {
    redirect("/dashboard");
  }

  const { uid } = await params;
  const user = await getUserDetail(uid);
  if (!user) notFound();

  const posts = await listUserPosts(uid);
  const fullName = `${user.firstName} ${user.lastName}`.trim() || "Adsız istifadəçi";

  return (
    <div className="mx-auto max-w-2xl space-y-6">
      <Link href="/users" className="inline-flex items-center gap-1.5 text-sm text-muted-foreground hover:text-foreground">
        <ArrowLeft className="size-4" />
        İstifadəçilərə qayıt
      </Link>

      <Card>
        <CardHeader>
          <div className="flex items-center gap-4">
            <Avatar className="size-16">
              <AvatarImage src={user.photoUrl ?? undefined} alt={fullName} />
              <AvatarFallback className="text-lg">{fullName.charAt(0).toUpperCase()}</AvatarFallback>
            </Avatar>
            <div>
              <CardTitle className="text-xl">{fullName}</CardTitle>
              <p className="text-sm text-muted-foreground">
                {user.username ? `@${user.username}` : "username yoxdur"}
              </p>
              <div className="mt-2 flex flex-wrap gap-1.5">
                <Badge variant={user.isVerified ? "default" : "outline"}>
                  {user.isVerified ? "Verified" : "Unverified"}
                </Badge>
                {user.premium && <Badge variant="secondary">VIP</Badge>}
                {user.banned && <Badge variant="destructive">Ban edilib</Badge>}
              </div>
            </div>
          </div>
        </CardHeader>
        <CardContent className="space-y-4">
          <dl className="grid grid-cols-2 gap-4 text-sm">
            <div>
              <dt className="text-muted-foreground">Telefon</dt>
              <dd className="font-medium">{user.phoneNumber ?? "Əlavə edilməyib"}</dd>
            </div>
            <div>
              <dt className="text-muted-foreground">Qeydiyyat tarixi</dt>
              <dd className="font-medium">{formatDate(user.createdAt)}</dd>
            </div>
            <div>
              <dt className="text-muted-foreground">UID</dt>
              <dd className="font-mono text-xs">{user.uid}</dd>
            </div>
          </dl>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle className="text-base">Əməliyyatlar</CardTitle>
        </CardHeader>
        <CardContent>
          <UserDetailActions user={user} />
        </CardContent>
      </Card>

      <UserPostsPanel uid={uid} posts={posts} />
    </div>
  );
}
