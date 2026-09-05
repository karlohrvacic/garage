/// The list a picker offers, widened to include a key this build does not
/// know.
///
/// Every one of the vehicle form's pickers is a `DropdownButtonFormField`,
/// which asserts in a debug build and renders blank in a release one when its
/// value matches none of its items. A blank field then saves as whatever the
/// form was holding, so a car stored by a newer build — or restored from a
/// backup taken by one — loses the very attribute this build could not name.
///
/// Widening the list keeps the stored key selected and saved. The label
/// functions already fall back to the raw key, so it shows as itself rather
/// than as an empty row: this build has no name for it, and inventing one
/// would be worse than admitting that.
List<String> keysIncludingStored(List<String> known, String? stored) {
  if (stored == null || known.contains(stored)) {
    return known;
  }
  return [...known, stored];
}
