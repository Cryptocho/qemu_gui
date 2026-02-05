class DiskImage {
  final String path;
  final String format;
  final String? size; // e.g., "20G"
  final String? backingFile;

  DiskImage({
    required this.path,
    this.format = 'qcow2',
    this.size,
    this.backingFile,
  });

  Map<String, dynamic> toJson() => {
        'path': path,
        'format': format,
        'size': size,
        'backingFile': backingFile,
      };

  factory DiskImage.fromJson(Map<String, dynamic> json) => DiskImage(
        path: json['path'],
        format: json['format'] ?? 'qcow2',
        size: json['size'],
        backingFile: json['backingFile'],
      );
}
