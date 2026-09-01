// Çat önizləməsi və oxunmamış sayğacı — dörd saatlıq dövrənin hasarı.
//
// Bu fayl `docs/`-dakı yeddi halın avtomatik yoxlanışıdır. Hər biri bir
// dəfə cihazda sınmışdı; burada sınsalar, cihaza çatmadan görünəcəklər.
import { describe, test } from "node:test";
import assert from "node:assert/strict";
import {
  ChatStateMessage,
  computeChatState,
  previewFor,
} from "../../functions/src/chat-state.ts";

const A = "userA";
const B = "userB";
const P = [A, B];

let clock = 1000;
function msg(over: Partial<ChatStateMessage> = {}): ChatStateMessage {
  clock += 1000;
  return {
    id: `m${clock}`,
    senderId: A,
    receiverId: B,
    type: "text",
    text: `t${clock}`,
    sentAtMs: clock,
    ...over,
  };
}
/** Newest-first, as the caller guarantees. */
const desc = (...m: ChatStateMessage[]) => [...m].sort((x, y) => y.sentAtMs - x.sentAtMs);

describe("Yeddi hal — hər iki tərəfin gördüyü", () => {
  test("1. normal mesaj — hər ikisi sonuncunu görür", () => {
    const m1 = msg({ text: "birinci" });
    const m2 = msg({ text: "sonuncu" });
    const s = computeChatState(desc(m1, m2), P);
    assert.equal(previewFor(s, A), "sonuncu");
    assert.equal(previewFor(s, B), "sonuncu");
    assert.deepEqual(s.override, {}, "override yazılmamalıdır");
  });

  test("2. A SON mesajı özü üçün silir — A əvvəlkini, B sonuncunu görür", () => {
    const m1 = msg({ text: "əvvəlki" });
    const m2 = msg({ text: "sonuncu", deletedFor: [A] });
    const s = computeChatState(desc(m1, m2), P);
    assert.equal(previewFor(s, A), "əvvəlki");
    assert.equal(previewFor(s, B), "sonuncu");
  });

  test("3. A KÖHNƏ mesajı özü üçün silir — hər ikisi sonuncunu görür", () => {
    // Override yazılmamalıdır: A-nın gördüyü sonuncu ortaq sonuncu ilə
    // eynidir. Yazılsaydı, o, mövcud olma səbəbindən uzun yaşayardı —
    // əsl qüsur məhz bu idi.
    const m1 = msg({ text: "köhnə", deletedFor: [A] });
    const m2 = msg({ text: "sonuncu" });
    const s = computeChatState(desc(m1, m2), P);
    assert.equal(previewFor(s, A), "sonuncu");
    assert.equal(previewFor(s, B), "sonuncu");
    assert.deepEqual(s.override, {});
  });

  test("4. A hamı üçün silir — hər ikisi əvvəlkini görür", () => {
    // Hamı üçün silmə sənədi yox edir, ona görə o, siyahıda yoxdur.
    const m1 = msg({ text: "əvvəlki" });
    const s = computeChatState(desc(m1), P);
    assert.equal(previewFor(s, A), "əvvəlki");
    assert.equal(previewFor(s, B), "əvvəlki");
    assert.deepEqual(s.override, {});
  });

  test("7. bütün mesajlar silinib — boş çat", () => {
    const s = computeChatState([], P);
    assert.equal(previewFor(s, A), "");
    assert.equal(previewFor(s, B), "");
    assert.equal(s.lastMessageAtMs, null);
    assert.deepEqual(s.override, {});
    assert.deepEqual(s.unread, { [A]: 0, [B]: 0 });
  });
});

describe("Oxunmamış sayğac", () => {
  test("zəng qeydi oxunmamış SAYILMIR — bugünkü qüsur", () => {
    // 46 «oxunmamış»ın hamısı zəng qeydi idi: heç nə onlara `readAt`
    // yazmır, çünki oxunacaq bir şey yoxdur.
    const calls = [msg({ type: "call" }), msg({ type: "call" }), msg({ type: "call" })];
    const s = computeChatState(desc(...calls), P);
    assert.equal(s.unread[B], 0);
  });

  test("oxunmamış mətn sayılır, oxunmuş sayılmır", () => {
    const unread = msg({ text: "yeni" });
    const read = msg({ text: "köhnə", readAtMs: 99999 });
    const s = computeChatState(desc(unread, read), P);
    assert.equal(s.unread[B], 1);
  });

  test("özüm üçün sildiyim mesaj mənə oxunmamış sayılmır", () => {
    const s = computeChatState(desc(msg({ deletedFor: [B] })), P);
    assert.equal(s.unread[B], 0);
  });

  test("göndərənin özünə oxunmamış yazılmır", () => {
    const s = computeChatState(desc(msg({ senderId: A, receiverId: B })), P);
    assert.equal(s.unread[A], 0);
    assert.equal(s.unread[B], 1);
  });

  test("silinmiş tipli mesaj sayılmır", () => {
    const s = computeChatState(desc(msg({ type: "deleted" })), P);
    assert.equal(s.unread[B], 0);
  });
});

describe("Ardıcıllıq — A silir, B yazır, A yenidən silir", () => {
  test("hər addımdan sonra hər iki tərəf doğru görür", () => {
    const m1 = msg({ text: "m1" });
    const m2 = msg({ text: "m2" });

    // Addım 1: A m2-ni özü üçün silir.
    m2.deletedFor = [A];
    let s = computeChatState(desc(m1, m2), P);
    assert.equal(previewFor(s, A), "m1");
    assert.equal(previewFor(s, B), "m2");

    // Addım 2: B yeni mesaj yazır. A-nın override-i köhnəlir və
    // AVTOMATİK yox olmalıdır — heç kim onu əl ilə silmir.
    const m3 = msg({ text: "m3", senderId: B, receiverId: A });
    s = computeChatState(desc(m1, m2, m3), P);
    assert.equal(previewFor(s, A), "m3", "yeni mesaj köhnə override-i əvəz etməlidir");
    assert.equal(previewFor(s, B), "m3");
    assert.deepEqual(s.override, {});

    // Addım 3: A m3-ü də özü üçün silir. İndi A m2-ni də silmişdi, ona
    // görə m1-ə düşməlidir — bir addım yox, iki addım geri.
    m3.deletedFor = [A];
    s = computeChatState(desc(m1, m2, m3), P);
    assert.equal(previewFor(s, A), "m1");
    assert.equal(previewFor(s, B), "m3");
  });

  test("A bütün mesajları özü üçün silir — ortağa düşür, çökmür", () => {
    const m1 = msg({ text: "m1", deletedFor: [A] });
    const m2 = msg({ text: "m2", deletedFor: [A] });
    const s = computeChatState(desc(m1, m2), P);
    // Görünən mesaj qalmayıb: override yazılmır, A ortaq önizləməni
    // görür. Boş sətir göstərmək daha pis olardı.
    assert.deepEqual(s.override, {});
    assert.equal(previewFor(s, A), "m2");
  });
});

describe("Eyni anda gələn mesajlar", () => {
  test("iki mesaj eyni millisaniyədə — nəticə deterministikdir", () => {
    // `recomputeChatState` son vəziyyəti oxuyur, ona görə iki trigger
    // eyni anda işləsə də ikisi də EYNİ nəticəni yazır.
    const a: ChatStateMessage = { ...msg({ text: "eyni-1" }), sentAtMs: 5000, id: "x1" };
    const b: ChatStateMessage = { ...msg({ text: "eyni-2" }), sentAtMs: 5000, id: "x2" };
    const s1 = computeChatState([a, b], P);
    const s2 = computeChatState([a, b], P);
    assert.deepEqual(s1, s2, "eyni girişdə eyni nəticə");
    assert.equal(s1.unread[B], 2, "hər ikisi sayılmalıdır");
  });

  test("idempotentdir — təkrar hesablama vəziyyəti dəyişmir", () => {
    const msgs = desc(msg({ text: "a" }), msg({ text: "b", deletedFor: [A] }));
    assert.deepEqual(computeChatState(msgs, P), computeChatState(msgs, P));
  });
});

describe("Çatın gizlədilməsi — hiddenFor", () => {
  // `hiddenFor` mesajlarda deyil, çat sənədindədir və `computeChatState`-ə
  // daxil deyil. Onu burada sənədləşdirirəm ki, yeddi halın hamısı bir
  // yerdə görünsün və heç biri «yaddan çıxmış» sayılmasın:
  //
  //   5. A çatı gizlədir       → `hiddenFor.A = true` (klient, öz açarı).
  //      Çat siyahısı `chats_tab.dart:110`-da SÜZÜLÜR, sorğuda yox.
  //      B tərəfdə heç nə dəyişmir — sahə uid-ə görədir.
  //
  //   6. Gizli çata yeni mesaj → `onChatMessageCreated` hər İKİ
  //      iştirakçı üçün `hiddenFor`-u `false` edir. Çat qayıdır və
  //      önizləmə yeni mesajdır, çünki eyni trigger recompute-u da
  //      çağırır.
  //
  // Bu ikisi önizləmə məntiqindən asılı deyil, ona görə burada saf
  // testləri yoxdur; sınmaları üçün `hiddenFor`-un öz yazıcısı dəyişməli
  // olardı, o isə `firestore.rules`-da təsbit edilib (yalnız öz açarı).
  test("hiddenFor önizləmə hesablamasına qarışmır", () => {
    // Sənədləşdirici test: `computeChatState` çat sənədinə deyil, yalnız
    // mesajlara baxır — yəni gizlətmə önizləməni dəyişdirə bilməz.
    const s = computeChatState(desc(msg({ text: "son" })), P);
    assert.equal(previewFor(s, A), "son");
    assert.equal(previewFor(s, B), "son");
  });
});
