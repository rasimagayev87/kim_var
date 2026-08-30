// P0 / C-3 — `AuthController.completeOnboarding` MÜTLƏQ xətanı yuxarı
// ötürməlidir.
//
// Bu, sırf "state düzgün qurulurmu" testi deyil. Kök səhv bu idi:
// controller `AsyncValue.guard` istifadə edirdi, guard isə xətanı tutub
// state-ə yazır və HEÇ VAXT rethrow etmir — `OnboardingScreen._finish`
// isə `await`-dan dərhal sonra şərtsiz `HomeScreen`-ə keçirdi. Nəticədə
// serverin 18+ / e-poçt təsdiqi / username yoxlamalarının hamısı
// effektiv olaraq mövcud deyildi: rədd edilən hesab yenə də tətbiqin
// içinə düşürdü.
//
// Ona görə burada yoxlanılan invariant budur: repository-nin atdığı HƏR
// xəta çağırana çatmalıdır (ekranın `catch` blokları yalnız bu halda
// işləyir və naviqasiya yalnız bu halda atlanır).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peakpin/features/auth/domain/entities/app_user.dart';
import 'package:peakpin/features/auth/domain/repositories/auth_repository.dart';
import 'package:peakpin/features/auth/presentation/providers/auth_providers.dart';

/// Yalnız `completeOnboarding`-i modelləşdirən minimal fake — qalan
/// metodlar bu testdə heç vaxt çağırılmır.
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.error, this.user});

  final Object? error;
  final AppUser? user;

  int completeOnboardingCalls = 0;

  @override
  Future<AppUser> completeOnboarding({
    required String username,
    required String firstName,
    required String lastName,
    required DateTime birthDate,
    required String gender,
    required String country,
    required String city,
    required String phoneNumber,
    required String businessStatus,
    String? bio,
  }) async {
    completeOnboardingCalls++;
    if (error != null) throw error!;
    return user!;
  }

  @override
  Future<AppUser?> restoreSession() async => null;

  @override
  bool get needsOnboarding => false;

  @override
  noSuchMethod(Invocation invocation) => throw UnimplementedError(
        'Bu testdə çağırılmamalıdır: ${invocation.memberName}',
      );
}

AppUser _user() => const AppUser(
      id: 'uid1',
      firstName: 'Ad',
      lastName: 'Soyad',
      username: 'adsoyad',
      loginProvider: LoginProvider.email,
    );

Future<void> _call(AuthController controller) => controller.completeOnboarding(
      username: 'adsoyad',
      firstName: 'Ad',
      lastName: 'Soyad',
      birthDate: DateTime(2000, 1, 1),
      gender: 'Kişi',
      country: 'Azərbaycan',
      city: 'Bakı',
      phoneNumber: '+994500000000',
      businessStatus: 'none',
    );

void main() {
  group('P0 / C-3 — completeOnboarding xəta ötürülməsi', () {
    test('18 yaşdan kiçik rəddi çağırana ötürülür (udulmur)', () async {
      final repo = _FakeAuthRepository(error: const UnderageOnboardingException());
      final controller = AuthController(repo);

      await expectLater(
        _call(controller),
        throwsA(isA<UnderageOnboardingException>()),
      );
      expect(repo.completeOnboardingCalls, 1);
      expect(controller.state.hasError, isTrue,
          reason: 'state hələ də xətanı daşımalıdır — rethrow onu əvəz etmir, əlavə edir');
    });

    test('təsdiqlənməmiş e-poçt rəddi çağırana ötürülür', () async {
      final controller = AuthController(_FakeAuthRepository(error: const EmailNotVerifiedException()));

      await expectLater(
        _call(controller),
        throwsA(isA<EmailNotVerifiedException>()),
      );
      expect(controller.state.hasError, isTrue);
    });

    test('digər hər hansı xəta da ötürülür (məs. tutulmuş username, rate limit)', () async {
      final controller = AuthController(_FakeAuthRepository(error: StateError('already-exists')));

      await expectLater(_call(controller), throwsA(isA<StateError>()));
      expect(controller.state.hasError, isTrue);
    });

    test('uğurlu hal: xəta atılmır və state istifadəçini daşıyır', () async {
      final controller = AuthController(_FakeAuthRepository(user: _user()));

      await _call(controller);

      expect(controller.state.hasError, isFalse);
      expect(controller.state.valueOrNull?.id, 'uid1');
    });
  });
}
