import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/venue_event.dart';

/// Shared localized label for [VenueEventCategory] — used by the
/// create form's dropdown, event cards, and the details screen, so all
/// three stay in sync automatically.
String eventCategoryLabel(AppLocalizations loc, VenueEventCategory category) =>
    switch (category) {
      VenueEventCategory.music => loc.eventCategoryMusic,
      VenueEventCategory.tasting => loc.eventCategoryTasting,
      VenueEventCategory.themeNight => loc.eventCategoryThemeNight,
      VenueEventCategory.other => loc.eventCategoryOther,
    };
