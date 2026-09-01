// Ödənilməmiş məkan seçilə bilirdi, forma doldurulurdu, sonda ümumi
// «Əməliyyat baş tutmadı» çıxırdı. Bu funksiya səbəbi ƏVVƏLCƏDƏN bilir.
import 'package:flutter_test/flutter_test.dart';
import 'package:peakpin/features/venues/domain/venue_listing_eligibility.dart';

void main() {
  group('venueListingBlock', () {
    test('yalnız approved icazəlidir', () {
      expect(venueListingBlock('approved'), isNull);
    });

    test('hər qeyri-approved status öz səbəbini qaytarır', () {
      expect(venueListingBlock('awaiting_payment'), VenueListingBlock.awaitingPayment);
      expect(venueListingBlock('pending'), VenueListingBlock.pending);
      expect(venueListingBlock('needs_revision'), VenueListingBlock.needsRevision);
      expect(venueListingBlock('rejected'), VenueListingBlock.rejected);
      expect(venueListingBlock('subscription_overdue'), VenueListingBlock.subscriptionOverdue);
    });

    test('naməlum status BLOKLANIR, icazə verilmir', () {
      // Ən vacib hal: gələcəkdə yeni status əlavə olunsa, o, səhvən
      // «icazəli» sayılmamalıdır — server onu onsuz da rədd edəcək və
      // istifadəçi yenidən ümumi xəta ilə qarşılaşardı.
      expect(venueListingBlock('yeni_status'), VenueListingBlock.unknown);
      expect(venueListingBlock(''), VenueListingBlock.unknown);
    });

    test('böyük hərf və boşluq icazə vermir', () {
      // Serverin müqayisəsi dəqiqdir; burada da elə olmalıdır.
      expect(venueListingBlock('APPROVED'), VenueListingBlock.unknown);
      expect(venueListingBlock(' approved'), VenueListingBlock.unknown);
    });
  });
}
