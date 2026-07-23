import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { LogoutButton } from "@/components/auth/logout-button";

export default function UnauthorizedPage() {
  return (
    <div className="flex flex-1 items-center justify-center bg-muted/30 p-6">
      <Card className="w-full max-w-sm text-center">
        <CardHeader>
          <CardTitle>İcazəniz yoxdur</CardTitle>
          <CardDescription>
            Bu hesabın admin panelə giriş üçün rolu yoxdur. Səlahiyyət lazımdırsa, mövcud bir
            admin ilə əlaqə saxlayın.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <LogoutButton />
        </CardContent>
      </Card>
    </div>
  );
}
