import "server-only";

import { getAdminDb } from "@/lib/firebase/admin";

export interface AdminPostRow {
  id: string;
  userId: string;
  mediaUrl: string;
  thumbnailUrl: string | null;
  mediaType: "photo" | "video";
  caption: string;
  likesCount: number;
  commentsCount: number;
  createdAt: string | null;
}

export interface AdminCommentRow {
  id: string;
  postId: string;
  userId: string;
  userName: string;
  text: string;
  createdAt: string | null;
}

const POSTS_LIMIT = 30;
const COMMENTS_LIMIT = 100;

export async function listUserPosts(uid: string): Promise<AdminPostRow[]> {
  const snap = await getAdminDb()
    .collection("posts")
    .where("userId", "==", uid)
    .orderBy("createdAt", "desc")
    .limit(POSTS_LIMIT)
    .get();

  return snap.docs.map((doc) => {
    const data = doc.data();
    const createdAt = data.createdAt as FirebaseFirestore.Timestamp | undefined;
    return {
      id: doc.id,
      userId: data.userId as string,
      mediaUrl: (data.mediaUrl as string) ?? "",
      thumbnailUrl: (data.thumbnailUrl as string) ?? null,
      mediaType: (data.mediaType as string) === "video" ? "video" : "photo",
      caption: (data.caption as string) ?? "",
      likesCount: (data.likesCount as number) ?? 0,
      commentsCount: (data.commentsCount as number) ?? 0,
      createdAt: createdAt ? createdAt.toDate().toISOString() : null,
    };
  });
}

export async function listPostComments(postId: string): Promise<AdminCommentRow[]> {
  const db = getAdminDb();
  const snap = await db.collection("posts").doc(postId).collection("comments").orderBy("createdAt").limit(COMMENTS_LIMIT).get();

  const userIds = [...new Set(snap.docs.map((doc) => doc.data().userId as string))];
  const userDocs = await Promise.all(userIds.map((uid) => db.collection("users").doc(uid).get()));
  const userByUid = new Map(userDocs.map((doc) => [doc.id, doc.data()]));

  return snap.docs.map((doc) => {
    const data = doc.data();
    const user = userByUid.get(data.userId as string);
    const createdAt = data.createdAt as FirebaseFirestore.Timestamp | undefined;
    return {
      id: doc.id,
      postId,
      userId: data.userId as string,
      userName: user ? `${user.firstName ?? ""} ${user.lastName ?? ""}`.trim() || "Naməlum" : "Naməlum",
      text: (data.text as string) ?? "",
      createdAt: createdAt ? createdAt.toDate().toISOString() : null,
    };
  });
}
