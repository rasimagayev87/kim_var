"use client";

import { useState, useTransition } from "react";
import { toast } from "sonner";

import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from "@/components/ui/alert-dialog";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { deletePost } from "@/lib/actions/content";
import type { AdminPostRow } from "@/lib/data/content";
import { PostCommentsSheet } from "./post-comments-sheet";

export function UserPostsPanel({ uid, posts }: { uid: string; posts: AdminPostRow[] }) {
  const [items, setItems] = useState(posts);
  const [openCommentsFor, setOpenCommentsFor] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  function handleDeletePost(postId: string) {
    startTransition(async () => {
      const result = await deletePost(postId, uid);
      if (result.ok) {
        setItems((prev) => prev.filter((post) => post.id !== postId));
        toast.success("Post silindi.");
      } else {
        toast.error("Post silinmədi.");
      }
    });
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-base">Paylaşımlar</CardTitle>
      </CardHeader>
      <CardContent>
        {items.length === 0 ? (
          <p className="text-sm text-muted-foreground">Bu istifadəçinin paylaşımı yoxdur.</p>
        ) : (
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-3">
            {items.map((post) => {
              const thumb = post.thumbnailUrl ?? (post.mediaType === "photo" ? post.mediaUrl : null);
              return (
                <div key={post.id} className="space-y-2 rounded-lg border p-2">
                  <div className="aspect-square overflow-hidden rounded-md bg-muted">
                    {thumb ? (
                      // eslint-disable-next-line @next/next/no-img-element -- admin tool, arbitrary user-hosted URLs, no next/image domain config
                      <img src={thumb} alt={post.caption || "post"} className="size-full object-cover" />
                    ) : (
                      <div className="flex size-full items-center justify-center text-xs text-muted-foreground">
                        Video
                      </div>
                    )}
                  </div>
                  <p className="line-clamp-2 text-xs text-muted-foreground">{post.caption || "—"}</p>
                  <div className="flex items-center justify-between gap-1">
                    <Button
                      variant="outline"
                      size="sm"
                      className="h-7 flex-1 text-xs"
                      onClick={() => setOpenCommentsFor(post.id)}
                    >
                      {post.commentsCount} şərh
                    </Button>
                    <AlertDialog>
                      <AlertDialogTrigger
                        render={
                          <Button variant="ghost" size="sm" className="h-7 text-xs text-destructive hover:text-destructive" disabled={pending} />
                        }
                      >
                        Sil
                      </AlertDialogTrigger>
                      <AlertDialogContent>
                        <AlertDialogHeader>
                          <AlertDialogTitle>Postu sil?</AlertDialogTitle>
                          <AlertDialogDescription>
                            Bu əməliyyat geri qaytarıla bilməz — post və onun şərhləri həmişəlik silinəcək.
                          </AlertDialogDescription>
                        </AlertDialogHeader>
                        <AlertDialogFooter>
                          <AlertDialogCancel>Ləğv et</AlertDialogCancel>
                          <AlertDialogAction onClick={() => handleDeletePost(post.id)}>Sil</AlertDialogAction>
                        </AlertDialogFooter>
                      </AlertDialogContent>
                    </AlertDialog>
                  </div>
                  {openCommentsFor === post.id && (
                    <PostCommentsSheet
                      postId={post.id}
                      postOwnerUid={uid}
                      open={openCommentsFor === post.id}
                      onOpenChange={(open) => setOpenCommentsFor(open ? post.id : null)}
                    />
                  )}
                </div>
              );
            })}
          </div>
        )}
      </CardContent>
    </Card>
  );
}
