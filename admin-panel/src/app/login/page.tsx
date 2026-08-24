"use client";

import { Suspense, useEffect, useState, type FormEvent } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { signInWithCustomToken, signInWithEmailAndPassword, type UserCredential } from "firebase/auth";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { getFirebaseAuth } from "@/lib/firebase/client";

// useSearchParams() requires a Suspense boundary above it, or Next
// fails the build trying to statically prerender this route.
export default function LoginPage() {
  return (
    <Suspense fallback={null}>
      <LoginForm />
    </Suspense>
  );
}

function LoginForm() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [submitting, setSubmitting] = useState(false);
  // True while an `?emergencyToken=` sign-in is in flight — hides the
  // normal form so it doesn't flash before the redirect.
  const [signingInWithToken, setSigningInWithToken] = useState(false);

  // Session creation (POST /api/auth/session → redirect) only cares
  // about the resulting ID token, not which provider produced the
  // credential — shared by both the normal form and the emergency
  // custom-token path below.
  async function completeSignIn(auth: ReturnType<typeof getFirebaseAuth>, credential: UserCredential) {
    const idToken = await credential.user.getIdToken();

    const response = await fetch("/api/auth/session", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ idToken }),
    });

    if (response.status === 403) {
      // Valid Firebase account, no admin/moderator role — never let
      // the client sit signed-in with nowhere it's allowed to go.
      await auth.signOut().catch(() => {});
      router.push("/unauthorized");
      return;
    }

    if (!response.ok) {
      throw new Error(`session-create-failed (${response.status})`);
    }

    router.push("/dashboard");
    router.refresh();
  }

  // TEMPORARY: stopgap for the Email+Password provider's project-wide
  // outage (see scripts/mint-emergency-token.ts's doc comment) — a
  // link minted by that script lands here with the token in the URL,
  // which this exchanges for a real session exactly like a normal
  // sign-in would, just via a different Firebase Auth provider. Remove
  // once Email+Password is confirmed working again; nothing else in
  // this file depends on it.
  useEffect(() => {
    const token = searchParams.get("emergencyToken");
    if (!token) return;

    setSigningInWithToken(true);
    const auth = getFirebaseAuth();
    signInWithCustomToken(auth, token)
      .then((credential) => completeSignIn(auth, credential))
      .catch((error) => {
        toast.error("Müvəqqəti giriş linki etibarsızdır və ya vaxtı bitib.");
        console.error(error);
        setSigningInWithToken(false);
      });
    // Only ever runs off the token that was in the URL on first render.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function handleSubmit(event: FormEvent) {
    event.preventDefault();
    if (submitting) return;
    setSubmitting(true);

    const auth = getFirebaseAuth();
    try {
      const credential = await signInWithEmailAndPassword(auth, email, password);
      await completeSignIn(auth, credential);
    } catch (error) {
      await auth.signOut().catch(() => {});
      toast.error("Giriş uğursuz oldu. E-poçt/parolu yoxlayın.");
      console.error(error);
    } finally {
      setSubmitting(false);
    }
  }

  if (signingInWithToken) {
    return (
      <div className="flex flex-1 items-center justify-center bg-muted/30 p-6">
        <p className="text-sm text-muted-foreground">Daxil olunur...</p>
      </div>
    );
  }

  return (
    <div className="flex flex-1 items-center justify-center bg-muted/30 p-6">
      <Card className="w-full max-w-sm">
        <CardHeader>
          <CardTitle>PeakPin Admin</CardTitle>
          <CardDescription>Davam etmək üçün admin hesabınızla daxil olun.</CardDescription>
        </CardHeader>
        <CardContent>
          <form className="space-y-4" onSubmit={handleSubmit}>
            <div className="space-y-2">
              <Label htmlFor="email">E-poçt</Label>
              <Input
                id="email"
                type="email"
                autoComplete="email"
                required
                value={email}
                onChange={(event) => setEmail(event.target.value)}
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="password">Parol</Label>
              <Input
                id="password"
                type="password"
                autoComplete="current-password"
                required
                value={password}
                onChange={(event) => setPassword(event.target.value)}
              />
            </div>
            <Button type="submit" className="w-full" disabled={submitting}>
              {submitting ? "Daxil olunur..." : "Daxil ol"}
            </Button>
          </form>
        </CardContent>
      </Card>
    </div>
  );
}
