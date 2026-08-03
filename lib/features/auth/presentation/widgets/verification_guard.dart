import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/premium_button.dart';
import '../screens/phone_auth_screen.dart';

/// Mirrors `isVerifiedUser()` in firestore.rules — true once
/// `users/{uid}.isVerified` (server-set only, by `markPhoneVerified`)
/// is `true`. Lives here rather than in the profile feature since it's
/// purely an auth/verification concern, not profile display data.
final isVerifiedProvider = StreamProvider<bool>((ref) {
  final uid = fb.FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(false);
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((doc) => doc.data()?['isVerified'] as bool? ?? false);
});

/// Client-side gate for verification-required actions (posting,
/// liking, commenting — anything firestore.rules' `isVerifiedUser()`
/// backstops server-side too). Returns true and does nothing if the
/// current user is already verified; otherwise shows a blocking
/// dialog and returns false so the caller can bail out of its action.
Future<bool> requireVerified(BuildContext context, WidgetRef ref) async {
  final isVerified = ref.read(isVerifiedProvider).valueOrNull ?? false;
  if (isVerified) return true;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.card,
      title: const Text(
        'Hesabı təsdiq et',
        style: TextStyle(color: AppColors.white),
      ),
      content: const Text(
        'Bu funksiyadan istifadə etmək üçün əvvəlcə hesabınızı təsdiqləməlisiniz.',
        style: TextStyle(color: AppColors.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Ləğv et'),
        ),
        PremiumButton(
          label: 'Hesabı təsdiq et',
          onPressed: () {
            Navigator.pop(dialogContext);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const PhoneAuthScreen()));
          },
        ),
      ],
    ),
  );
  return false;
}
