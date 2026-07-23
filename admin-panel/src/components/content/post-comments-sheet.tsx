"use client";

import { useState, useTransition } from "react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet";
import { deleteComment, fetchPostComments } from "@/lib/actions/content";
import type { AdminCommentRow } from "@/lib/data/content";

function formatDate(iso: string | null): string {
  if (!iso) return "—";
  return new Date(iso).toLocaleDateString("az-AZ", { year: "numeric", month: "short", day: "numeric" });
}

export function PostCommentsSheet({
  postId,
  postOwnerUid,
  open,
  onOpenChange,
}: {
  postId: string;
  postOwnerUid: string;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}) {
  const [comments, setComments] = useState<AdminCommentRow[] | null>(null);
  const [loading, setLoading] = useState(false);
  const [pending, startTransition] = useTransition();

  async function handleOpenChange(next: boolean) {
    onOpenChange(next);
    if (next && comments === null) {
      setLoading(true);
      const result = await fetchPostComments(postId);
      setLoading(false);
      if ("error" in result) {
        toast.error("Şərhlər yüklənmədi.");
        return;
      }
      setComments(result);
    }
  }

  function handleDelete(commentId: string) {
    startTransition(async () => {
      const result = await deleteComment(postId, commentId, postOwnerUid);
      if (result.ok) {
        setComments((prev) => prev?.filter((comment) => comment.id !== commentId) ?? null);
        toast.success("Şərh silindi.");
      } else {
        toast.error("Şərh silinmədi.");
      }
    });
  }

  return (
    <Sheet open={open} onOpenChange={handleOpenChange}>
      <SheetContent>
        <SheetHeader>
          <SheetTitle>Şərhlər</SheetTitle>
          <SheetDescription>Uyğunsuz şərhi buradan silə bilərsiniz.</SheetDescription>
        </SheetHeader>
        <div className="flex-1 space-y-3 overflow-y-auto px-4 pb-4">
          {loading && <p className="text-sm text-muted-foreground">Yüklənir...</p>}
          {comments?.length === 0 && <p className="text-sm text-muted-foreground">Şərh yoxdur.</p>}
          {comments?.map((comment) => (
            <div key={comment.id} className="rounded-lg border p-3">
              <div className="flex items-start justify-between gap-3">
                <div>
                  <p className="text-sm font-medium">{comment.userName}</p>
                  <p className="text-sm text-muted-foreground">{comment.text}</p>
                  <p className="mt-1 text-xs text-muted-foreground">{formatDate(comment.createdAt)}</p>
                </div>
                <Button
                  variant="ghost"
                  size="sm"
                  className="text-destructive hover:text-destructive"
                  disabled={pending}
                  onClick={() => handleDelete(comment.id)}
                >
                  Sil
                </Button>
              </div>
            </div>
          ))}
        </div>
      </SheetContent>
    </Sheet>
  );
}
