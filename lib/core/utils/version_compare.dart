/// Compares two dotted version strings (e.g. `"1.9.0"` vs `"1.10.0"`)
/// numerically, segment by segment — a plain string comparison would get
/// `"1.10.0" < "1.9.0"` wrong. Returns the same contract as [Comparable]:
/// negative if [a] < [b], zero if equal, positive if [a] > [b].
///
/// A malformed or empty string in either argument makes that segment
/// compare as `0` — never throws, since this backs update-gating logic
/// that must fail safe (see [_segments]'s own doc comment).
int compareVersions(String a, String b) {
  final segmentsA = _segments(a);
  final segmentsB = _segments(b);
  final length = segmentsA.length > segmentsB.length
      ? segmentsA.length
      : segmentsB.length;
  for (var i = 0; i < length; i++) {
    final partA = i < segmentsA.length ? segmentsA[i] : 0;
    final partB = i < segmentsB.length ? segmentsB[i] : 0;
    if (partA != partB) return partA.compareTo(partB);
  }
  return 0;
}

/// Splits on `.` and parses each part as an int; a non-numeric or missing
/// part becomes `0` rather than throwing — a malformed version string
/// (e.g. from a corrupted Remote Config value) should compare as
/// harmlessly low, not crash the caller.
List<int> _segments(String version) {
  return version
      .split('.')
      .map((part) => int.tryParse(part.trim()) ?? 0)
      .toList();
}
