import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/vip_feature.dart';

const vipFeatureIconsByKey = <String, IconData>{
  'ghost': Icons.visibility_off_outlined,
  'radius': Icons.radar_outlined,
  'filter': Icons.tune_outlined,
  'star': Icons.star_outline,
};

/// Backed by the `vipFeatures` Firestore collection (docs ordered by
/// `order`, fields: title/description/icon) so marketing copy can be
/// changed without a release. Returns an empty list until that
/// collection is populated — [VipScreen] falls back to a localized
/// default list (describing real, already-shipped features: Ghost
/// Mode, 5/10 km radius, gender filter) only in that case, so the
/// screen isn't blank on first launch.
final vipFeaturesProvider = StreamProvider.autoDispose<List<VipFeature>>((ref) {
  return FirebaseFirestore.instance.collection('vipFeatures').orderBy('order').snapshots().map((snap) {
    return snap.docs.map((d) {
      final data = d.data();
      return VipFeature(
        icon: vipFeatureIconsByKey[data['icon'] as String?] ?? Icons.star_outline,
        title: data['title'] as String? ?? '',
        description: data['description'] as String? ?? '',
      );
    }).toList();
  });
});
