/**
 * The chat list's derived state, as a pure function.
 *
 * `lastMessage`, `lastMessageOverride` and `unreadCount` used to be
 * maintained incrementally by three separate triggers — one on send,
 * one on delete-for-everyone, one on delete-for-me — and each forgot at
 * least one of the others' fields. The visible results were a preview
 * frozen on a day-old message, a preview that survived deleting the
 * message it described, an unread badge counting a message that no
 * longer existed, and 46 phantom unread messages that were all call
 * records.
 *
 * Every one of those values is a function of the messages in the chat,
 * so it is computed here and nowhere else. Kept free of Firestore types
 * on purpose: the seven cases this has to get right are exactly the
 * ones that kept regressing, and they are only cheap to test if the
 * logic can be called with plain objects.
 */

export interface ChatStateMessage {
  id: string;
  senderId: string;
  receiverId: string;
  type: string;
  text?: string;
  /** Milliseconds. Newest-first ordering is the caller's job. */
  sentAtMs: number;
  /** Absent/undefined means never read. */
  readAtMs?: number | null;
  /** uids for whom this message is hidden ("məndən sil"). */
  deletedFor?: string[];
}

export interface ChatStateResult {
  lastMessage: string;
  lastMessageType: string;
  lastMessageAtMs: number | null;
  lastMessageSenderId: string | null;
  /** Only participants whose visible newest differs from the shared one. */
  override: Record<string, { text: string; type: string; atMs: number }>;
  unread: Record<string, number>;
}

/**
 * Message types that are records of something, not something to read.
 *
 * Nothing ever writes `readAt` on a call entry, so "no readAt means
 * unread" turned every past call into an unread message — 46 in one
 * chat against zero real ones. The old incremental counter never hit
 * this because it only counted on a real send.
 */
const NON_READABLE_TYPES = new Set(["call", "deleted"]);

/** [messages] must be sorted newest-first. */
export function computeChatState(
  messages: ChatStateMessage[],
  participants: string[],
): ChatStateResult {
  const unread: Record<string, number> = {};
  for (const uid of participants) {
    unread[uid] = messages.filter(
      (m) =>
        m.receiverId === uid &&
        !NON_READABLE_TYPES.has(m.type) &&
        !m.readAtMs &&
        !(m.deletedFor ?? []).includes(uid),
    ).length;
  }

  if (messages.length === 0) {
    return {
      lastMessage: "",
      lastMessageType: "deleted",
      lastMessageAtMs: null,
      lastMessageSenderId: null,
      override: {},
      unread,
    };
  }

  const newest = messages[0];
  const override: ChatStateResult["override"] = {};
  for (const uid of participants) {
    const visible = messages.find((m) => !(m.deletedFor ?? []).includes(uid));
    // Same as the shared preview → no override. This is what stops an
    // override outliving the reason it was written.
    if (!visible || visible.id === newest.id) continue;
    override[uid] = {
      text: visible.text ?? "",
      type: visible.type,
      atMs: visible.sentAtMs,
    };
  }

  return {
    lastMessage: newest.text ?? "",
    lastMessageType: newest.type,
    lastMessageAtMs: newest.sentAtMs,
    lastMessageSenderId: newest.senderId,
    override,
    unread,
  };
}

/** What [uid] should see in the chat list. */
export function previewFor(state: ChatStateResult, uid: string): string {
  return state.override[uid]?.text ?? state.lastMessage;
}
