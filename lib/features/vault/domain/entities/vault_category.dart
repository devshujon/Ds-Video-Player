/// Categories shown on the vault home screen.
enum VaultCategory {
  videos('video', 'Private Videos', 'Videos secured in your vault'),
  images('image', 'Private Images', 'Photos and pictures'),
  audio('audio', 'Private Audio', 'Music and sound files'),
  documents('document', 'Private Documents', 'PDFs, docs, and archives'),
  downloads('download', 'Private Downloads', 'Files from Downloads'),
  folders('folder', 'Folders', 'Locked folder contents');

  const VaultCategory(this.id, this.title, this.subtitle);

  final String id;
  final String title;
  final String subtitle;

  static VaultCategory? fromId(String id) {
    for (final c in VaultCategory.values) {
      if (c.id == id) return c;
    }
    return null;
  }
}
