/// Pure matching helpers for the approved-business directory search.
class BusinessSearch {
  const BusinessSearch._();

  /// Whether [name]/[code] should appear for a normalized [query]
  /// (already trimmed + lowercased by the caller).
  ///
  /// Accepts full/partial name, exact or partial shop code, and
  /// multi-word queries where every token appears in the name (so
  /// "dime shop" matches) or any token of 3+ chars matches (so
  /// "dime store" still surfaces "Dime shop").
  static bool matches({
    required String name,
    required String code,
    required String query,
  }) {
    if (query.isEmpty) return false;
    if (code == query || code.contains(query) || name.contains(query)) {
      return true;
    }
    final tokens = query
        .split(RegExp(r'\s+'))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    if (tokens.length < 2) return false;
    if (tokens.every((t) => name.contains(t) || code.contains(t))) {
      return true;
    }
    return tokens.any((t) => t.length >= 3 && name.contains(t));
  }
}
