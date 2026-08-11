/// Curated country + city data, reused from the phone country-code
/// list for consistency across the app. This intentionally covers
/// the launch markets in depth and major global cities elsewhere,
/// rather than an exhaustive worldwide database — expand
/// [kCitiesByCountry] as new markets are added.
const kCountryNames = <String>[
  'Azərbaycan',
  'Türkiyə',
  'Gürcüstan',
  'Rusiya',
  'Qazaxıstan',
  'Özbəkistan',
  'Ukrayna',
  'İran',
  'BƏƏ',
  'Səudiyyə Ərəbistanı',
  'İsrail',
  'Almaniya',
  'Fransa',
  'İtaliya',
  'İspaniya',
  'Niderland',
  'Polşa',
  'Böyük Britaniya',
  'ABŞ',
  'Kanada',
  'Çin',
  'Hindistan',
];

/// Maps a country name from an uncontrolled source (the `geocoding`
/// plugin's reverse-geocode result, which returns whatever spelling
/// the OS's own geocoder feels like — e.g. "Azerbaycan" without the
/// "ə") onto this list's exact spelling, so a value that ultimately
/// traces back to a device geocoder still string-equals a value that
/// traces back to [kCountryNames] itself (e.g. `UserProfile.country`,
/// picked from this same list) — those two need to compare equal for
/// country-scoped queries like `_countryCandidatesProvider` to find a
/// venue/user at all. Falls back to [raw] unchanged if nothing in the
/// list matches even after folding diacritics — better to keep an
/// unrecognized country visible under its own name than drop it.
String? canonicalCountryName(String? raw) {
  if (raw == null || raw.trim().isEmpty) return raw;
  final target = _foldCountryKey(raw);
  for (final name in kCountryNames) {
    if (_foldCountryKey(name) == target) return name;
  }
  return raw;
}

String _foldCountryKey(String s) {
  return s
      .replaceAll('ə', 'e')
      .replaceAll('Ə', 'e')
      .replaceAll('ı', 'i')
      .replaceAll('İ', 'i')
      .replaceAll('I', 'i')
      .replaceAll('ö', 'o')
      .replaceAll('Ö', 'o')
      .replaceAll('ü', 'u')
      .replaceAll('Ü', 'u')
      .replaceAll('ş', 's')
      .replaceAll('Ş', 's')
      .replaceAll('ç', 'c')
      .replaceAll('Ç', 'c')
      .replaceAll('ğ', 'g')
      .replaceAll('Ğ', 'g')
      .toLowerCase()
      .trim();
}

const kCitiesByCountry = <String, List<String>>{
  'Azərbaycan': [
    'Bakı', 'Gəncə', 'Sumqayıt', 'Mingəçevir', 'Naxçıvan', 'Şəki',
    'Lənkəran', 'Şirvan', 'Yevlax', 'Naftalan', 'Qəbələ', 'Quba',
    'Xankəndi', 'Astara', 'Zaqatala', 'Şamaxı', 'Qusar', 'Göyçay',
    'Ağdam', 'Bərdə', 'Salyan', 'Neftçala', 'Qax', 'İmişli',
  ],
  'Türkiyə': [
    'İstanbul', 'Ankara', 'İzmir', 'Bursa', 'Antalya', 'Adana',
    'Konya', 'Gaziantep', 'Trabzon', 'Mersin', 'Kayseri', 'Eskişehir',
  ],
  'Gürcüstan': ['Tbilisi', 'Batumi', 'Kutaisi', 'Rustavi', 'Gori', 'Zugdidi'],
  'Rusiya': ['Moskva', 'Sankt-Peterburq', 'Kazan', 'Novosibirsk', 'Yekaterinburq', 'Soçi'],
  'Qazaxıstan': ['Almatı', 'Astana', 'Şımkənt', 'Qaraqandı', 'Aktau'],
  'Özbəkistan': ['Daşkənd', 'Səmərqənd', 'Buxara', 'Namangan', 'Xiva'],
  'Ukrayna': ['Kiyev', 'Xarkov', 'Odessa', 'Lvov', 'Dnepr'],
  'İran': ['Tehran', 'Təbriz', 'İsfahan', 'Məşhəd', 'Şiraz'],
  'BƏƏ': ['Dubay', 'Əbu-Dabi', 'Şarcə', 'Əcman'],
  'Səudiyyə Ərəbistanı': ['Riyad', 'Cidda', 'Məkkə', 'Mədinə', 'Dəmmam'],
  'İsrail': ['Yerusəlim', 'Tel-Əviv', 'Hayfa', 'Beer-Şeva'],
  'Almaniya': ['Berlin', 'Münhen', 'Hamburq', 'Köln', 'Frankfurt'],
  'Fransa': ['Paris', 'Marsel', 'Lion', 'Tuluza', 'Nitsa'],
  'İtaliya': ['Roma', 'Milan', 'Neapol', 'Turin', 'Florensiya'],
  'İspaniya': ['Madrid', 'Barselona', 'Valensiya', 'Sevilya'],
  'Niderland': ['Amsterdam', 'Rotterdam', 'Haaqa', 'Utrext'],
  'Polşa': ['Varşava', 'Krakov', 'Vroslav', 'Poznan'],
  'Böyük Britaniya': ['London', 'Mançester', 'Birmingem', 'Liverpul', 'Qlazqo'],
  'ABŞ': ['Nyu-York', 'Los-Anceles', 'Çikaqo', 'Hyuston', 'Mayami'],
  'Kanada': ['Toronto', 'Vankuver', 'Montreal', 'Otava'],
  'Çin': ['Pekin', 'Şanxay', 'Guançjou', 'Şençjen'],
  'Hindistan': ['Dehli', 'Mumbay', 'Banqalor', 'Çennay'],
};
