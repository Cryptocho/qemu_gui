import 'package:path/path.dart' as p;

class SharedFolder {
  final String path; // absolute host directory path
  final String mountTag; // guest-visible 9p mount tag (also used by QEMU as fsdev id)
  final bool readOnly;

  SharedFolder({
    required this.path,
    required this.mountTag,
    this.readOnly = false,
  });

  Map<String, dynamic> toJson() => {
        'path': path,
        'mountTag': mountTag,
        'readOnly': readOnly,
      };

  factory SharedFolder.fromJson(Map<String, dynamic> json) => SharedFolder(
        path: json['path'],
        mountTag: json['mountTag'] ?? sanitizeMountTag(p.basename(json['path'] ?? '')),
        readOnly: json['readOnly'] ?? false,
      );

  /// Enforces the charset QEMU accepts for the auto-derived fsdev id:
  /// first char must be an ASCII letter, remainder [A-Za-z0-9._-].
  /// Runs of invalid characters collapse to a single '_'
  /// ('My Docs' -> 'My_Docs'); no alphanumerics -> 'share';
  /// non-letter start gets a 'share_' prefix ('2024' -> 'share_2024').
  static String sanitizeMountTag(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    if (!RegExp(r'[A-Za-z0-9]').hasMatch(cleaned)) return 'share';
    return RegExp(r'^[A-Za-z]').hasMatch(cleaned) ? cleaned : 'share_$cleaned';
  }

  /// Generates a unique tag per VM from the folder's basename.
  static String generateMountTag(String hostPath, List<String> takenTags) {
    final base = sanitizeMountTag(p.basename(hostPath));
    var tag = base;
    var i = 2;
    while (takenTags.contains(tag)) {
      tag = '${base}_$i';
      i++;
    }
    return tag;
  }

  /// Whether [tag] satisfies the charset QEMU accepts for the auto-derived
  /// fsdev id: must start with an ASCII letter, remainder [A-Za-z0-9._-].
  /// Used for user-edited tags (generation always sanitizes instead).
  static bool isValidMountTag(String tag) =>
      RegExp(r'^[A-Za-z][A-Za-z0-9._-]*$').hasMatch(tag);
}
