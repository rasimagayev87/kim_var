import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../domain/entities/vip_feature.dart';
import 'vip_purchase_listener.dart';

const vipFeatureIconsByKey = <String, IconData>{
  'ghost': Icons.visibility_off_outlined,
  'radius': Icons.radar_outlined,
  'filter': Icons.tune_outlined,
  'visitors': Icons.directions_walk,
  'incognito': Icons.explore_off_outlined,
  'priority': Icons.bolt_outlined,
  'star': Icons.star_outline,
};

/// Backed by the `vipFeatures` Firestore collection (docs ordered by
/// `order`, fields: title/description/icon) so marketing copy can be
/// changed without a release. Returns an empty list until that
/// collection is populated — [VipScreen] falls back to a localized
/// default list (describing real, already-shipped features: Ghost
/// Mode, Ölkə/Dünya radius, gender filter, profile viewers, incognito
/// browsing, priority message requests) only in that case, so the
/// screen isn't blank on first launch.
/// Live store product listing for [kVipPackages] — [VipScreen] reads
/// each period's real, store-localized price from this instead of a
/// hardcoded string. See `queryVipProducts`'s own doc comment for why
/// this can legitimately come back empty (store unreachable, or the
/// subscription products don't exist in App Store Connect/Play Console
/// yet).
final vipProductsProvider = FutureProvider.autoDispose<List<ProductDetails>>((ref) => queryVipProducts());

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
