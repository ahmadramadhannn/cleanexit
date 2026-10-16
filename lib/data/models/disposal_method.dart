/// How the app should get rid of a file the user did NOT keep.
/// Chosen per cleanup run (project decision: "Ask each").
enum DisposalMethod {
  /// Move to the OS Recycle Bin / XDG Trash. Recoverable until emptied.
  recycle,

  /// Move into CleanExit's private vault; restorable from the History tab.
  vault,

  /// Overwrite with zeroes, then delete. No recovery possible.
  shred,
}

extension DisposalMethodX on DisposalMethod {
  String get label => switch (this) {
        DisposalMethod.recycle => 'Recycle Bin',
        DisposalMethod.vault => 'Vault (restorable)',
        DisposalMethod.shred => 'Shred permanently',
      };

  String get description => switch (this) {
        DisposalMethod.recycle =>
          'Items go to the OS trash. Anyone with a bit of effort can restore them — fine for most sessions.',
        DisposalMethod.vault =>
          'CleanExit hides the items in its own vault. You can restore everything later from History.',
        DisposalMethod.shred =>
          'Overwrites the data with zeroes before deleting. Nothing comes back — double-check your keep list.',
      };

  String get jsonValue => name;

  static DisposalMethod fromJson(String v) => DisposalMethod.values
      .firstWhere((m) => m.name == v, orElse: () => DisposalMethod.recycle);
}
