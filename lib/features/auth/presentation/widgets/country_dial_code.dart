class CountryDialCode {
  final String name;
  final String dialCode;
  final String flag;

  const CountryDialCode({required this.name, required this.dialCode, required this.flag});
}

/// A curated list of dial codes prioritising the app's launch
/// markets (Azerbaijan first), plus common global destinations.
/// Expand as the app reaches new markets.
const kCountryDialCodes = <CountryDialCode>[
  CountryDialCode(name: 'Azərbaycan', dialCode: '+994', flag: '🇦🇿'),
  CountryDialCode(name: 'Türkiyə', dialCode: '+90', flag: '🇹🇷'),
  CountryDialCode(name: 'Gürcüstan', dialCode: '+995', flag: '🇬🇪'),
  CountryDialCode(name: 'Rusiya', dialCode: '+7', flag: '🇷🇺'),
  CountryDialCode(name: 'Qazaxıstan', dialCode: '+7', flag: '🇰🇿'),
  CountryDialCode(name: 'Özbəkistan', dialCode: '+998', flag: '🇺🇿'),
  CountryDialCode(name: 'Ukrayna', dialCode: '+380', flag: '🇺🇦'),
  CountryDialCode(name: 'İran', dialCode: '+98', flag: '🇮🇷'),
  CountryDialCode(name: 'BƏƏ', dialCode: '+971', flag: '🇦🇪'),
  CountryDialCode(name: 'Səudiyyə Ərəbistanı', dialCode: '+966', flag: '🇸🇦'),
  CountryDialCode(name: 'İsrail', dialCode: '+972', flag: '🇮🇱'),
  CountryDialCode(name: 'Almaniya', dialCode: '+49', flag: '🇩🇪'),
  CountryDialCode(name: 'Fransa', dialCode: '+33', flag: '🇫🇷'),
  CountryDialCode(name: 'İtaliya', dialCode: '+39', flag: '🇮🇹'),
  CountryDialCode(name: 'İspaniya', dialCode: '+34', flag: '🇪🇸'),
  CountryDialCode(name: 'Niderland', dialCode: '+31', flag: '🇳🇱'),
  CountryDialCode(name: 'Polşa', dialCode: '+48', flag: '🇵🇱'),
  CountryDialCode(name: 'Böyük Britaniya', dialCode: '+44', flag: '🇬🇧'),
  CountryDialCode(name: 'ABŞ', dialCode: '+1', flag: '🇺🇸'),
  CountryDialCode(name: 'Kanada', dialCode: '+1', flag: '🇨🇦'),
  CountryDialCode(name: 'Çin', dialCode: '+86', flag: '🇨🇳'),
  CountryDialCode(name: 'Hindistan', dialCode: '+91', flag: '🇮🇳'),
];
