/// A rectangular bounding box (south-west/north-east corners) —
/// deliberately plain data, no `google_maps_flutter` dependency here,
/// so the domain layer stays plugin-free; the presentation layer
/// converts this to a `LatLngBounds` where it actually draws the map.
class CountryBounds {
  final double swLat;
  final double swLng;
  final double neLat;
  final double neLng;

  const CountryBounds({
    required this.swLat,
    required this.swLng,
    required this.neLat,
    required this.neLng,
  });
}

/// Approximate bounding boxes for the same 22 curated countries as
/// [kCountryNames]/[kCountryDialCodes] — "Ölkə üzrə" animates the map
/// camera to fit one of these. Deliberately approximate rectangles,
/// not true polygon borders (which `LatLngBounds`/`newLatLngBounds`
/// can't represent anyway); Russia and the US are trimmed to their
/// main landmass (excluding the far-eastern Chukotka peninsula past
/// the antimeridian, and Alaska/Hawaii respectively) to avoid the
/// antimeridian-wraparound edge case entirely.
const kCountryBounds = <String, CountryBounds>{
  'Azərbaycan': CountryBounds(swLat: 38.4, swLng: 44.8, neLat: 41.9, neLng: 50.4),
  'Türkiyə': CountryBounds(swLat: 35.8, swLng: 25.6, neLat: 42.1, neLng: 44.8),
  'Gürcüstan': CountryBounds(swLat: 41.0, swLng: 40.0, neLat: 43.6, neLng: 46.7),
  'Rusiya': CountryBounds(swLat: 41.2, swLng: 19.6, neLat: 81.9, neLng: 179.9),
  'Qazaxıstan': CountryBounds(swLat: 40.6, swLng: 46.5, neLat: 55.4, neLng: 87.3),
  'Özbəkistan': CountryBounds(swLat: 37.2, swLng: 55.9, neLat: 45.6, neLng: 73.1),
  'Ukrayna': CountryBounds(swLat: 44.4, swLng: 22.1, neLat: 52.4, neLng: 40.2),
  'İran': CountryBounds(swLat: 25.1, swLng: 44.0, neLat: 39.8, neLng: 63.3),
  'BƏƏ': CountryBounds(swLat: 22.6, swLng: 51.5, neLat: 26.1, neLng: 56.4),
  'Səudiyyə Ərəbistanı': CountryBounds(swLat: 16.0, swLng: 34.5, neLat: 32.2, neLng: 55.7),
  'İsrail': CountryBounds(swLat: 29.5, swLng: 34.2, neLat: 33.3, neLng: 35.9),
  'Almaniya': CountryBounds(swLat: 47.3, swLng: 5.9, neLat: 55.1, neLng: 15.0),
  'Fransa': CountryBounds(swLat: 41.3, swLng: -5.2, neLat: 51.1, neLng: 9.6),
  'İtaliya': CountryBounds(swLat: 35.5, swLng: 6.6, neLat: 47.1, neLng: 18.5),
  'İspaniya': CountryBounds(swLat: 36.0, swLng: -9.3, neLat: 43.8, neLng: 4.3),
  'Niderland': CountryBounds(swLat: 50.8, swLng: 3.3, neLat: 53.6, neLng: 7.2),
  'Polşa': CountryBounds(swLat: 49.0, swLng: 14.1, neLat: 54.8, neLng: 24.2),
  'Böyük Britaniya': CountryBounds(swLat: 49.9, swLng: -8.6, neLat: 60.9, neLng: 1.8),
  'ABŞ': CountryBounds(swLat: 24.4, swLng: -125.0, neLat: 49.4, neLng: -66.9),
  'Kanada': CountryBounds(swLat: 41.7, swLng: -141.0, neLat: 83.1, neLng: -52.6),
  'Çin': CountryBounds(swLat: 18.2, swLng: 73.5, neLat: 53.6, neLng: 134.8),
  'Hindistan': CountryBounds(swLat: 6.7, swLng: 68.1, neLat: 35.5, neLng: 97.4),
};
