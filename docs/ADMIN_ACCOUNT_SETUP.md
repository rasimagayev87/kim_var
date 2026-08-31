# Admin panel — yeni hesab yaratma proseduru

**Bu sənəd yalnız addımları yazır. Heç bir hesab yaradılmayıb, heç bir
parol yaradılmayıb və heç yerdə saxlanılmayıb.** Parolu siz təyin
edirsiniz; o, nə bu repoda, nə bir skriptdə, nə də bir log-da
görünməməlidir.

## Bir hesabın iki hissəsi var

| Hissə | Nə üçün | Kim yazır |
|---|---|---|
| `role` **custom claim** | **Авторizasiya** — sessiya cookie-si yalnız bu claim varsa verilir (`createSessionFromIdToken`), və hər icazə yoxlaması ondan oxunur | `addAdmin` Server Action |
| `admins/{uid}` **sənədi** | Yalnız `/admins` siyahısını göstərmək üçün indeks | eyni action |

Claim olmadan hesab panelə **girə bilmir**, sənəd nə qədər düzgün
olsa da. Sənəd olmadan hesab işləyir, sadəcə siyahıda görünmür.
Buna görə hər ikisini eyni yerdən — `addAdmin` — yaratmaq lazımdır;
əl ilə yalnız birini yazmaq drift deməkdir.

## Addımlar

1. **Firebase Console → Authentication → Users → Add user.**
   E-poçt: `rol@peakpin.app` formasında. Parolu özünüz təyin edin.
   Güclü, təkrarlanmayan parol seçin və onu **parol menecerinizdə**
   saxlayın — bu sənədə, mesaja və ya fayla yazmayın.

2. **UID-i kopyalayın** (Console-dakı istifadəçi sətrindən).

3. **`admin` rolu olan hesabla `admin.peakpin.app`-a daxil olun** və
   **`/admins` → «Admin əlavə et»**. E-poçtu yazın, rolu seçin
   (Admin / Moderator / Maliyyə / Dəstək / Analitik), təsdiqləyin.
   Bu, custom claim-i və roster sənədini birlikdə yazır.

4. **Yeni hesabla daxil olun.** İlk girişdə parolun dəyişdirilməsini
   istəyin (sahibinin özü Firebase-in «Şifrəni unutdum» axını ilə
   dəyişsin — beləcə parolu heç kim, siz də daxil olmaqla, bilmir).

5. **Yoxlayın:** `/admins`-də rol düzgün adla görünür (Maliyyə, Dəstək,
   Analitik — «naməlum rol» YOX), və rolun görməməli olduğu bir
   səhifə (məsələn analyst üçün `/users`) `/unauthorized`-a aparır.

## Rolun dəyişdirilməsi və silinməsi

`/admins` səhifəsindən. Üç qoruma qüvvədədir və hamısı serverdədir:

* Öz rolunuzu dəyişə və özünüzü silə bilməzsiniz.
* Tanınmayan rol qəbul edilmir.
* **Sonuncu admin** rolundan salına və ya silinə bilməz — əks halda
  panelin idarəçisi qalmazdı.

## Nə etməyin

* Custom claim-i Firebase Console-dan əl ilə yazmayın — roster sənədi
  ilə drift yaradır və `/admins` yanlış göstərir.
* `admins/{uid}` sənədini əl ilə redaktə etməyin. O, авторizasiya
  mənbəyi **deyil**: sənədə `role: "admin"` yazmaq heç bir icazə
  vermir, çünki heç bir yoxlama ona baxmır.
* Parolu heç bir sənədə, skriptə və ya söhbətə yazmayın.
