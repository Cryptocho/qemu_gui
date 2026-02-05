import 'dart:io';

class ImageService {
  final String qemuImgPath;

  ImageService(this.qemuImgPath);

  Future<String> createImg(String path, String size, {String format = 'qcow2'}) async {
    try {
      final result = await Process.run(qemuImgPath, ['create', '-f', format, path, size]);
      if (result.exitCode == 0) {
        return result.stdout.toString();
      }
      return 'Error: ${result.stderr}';
    } catch (e) {
      return 'Error: $e';
    }
  }

  Future<String> getInfo(String path) async {
    try {
      final result = await Process.run(qemuImgPath, ['info', path]);
      if (result.exitCode == 0) {
        return result.stdout.toString();
      }
      return 'Error: ${result.stderr}';
    } catch (e) {
      return 'Error: $e';
    }
  }

  Future<String> resizeImg(String path, String delta) async {
    try {
      final result = await Process.run(qemuImgPath, ['resize', path, delta]);
      if (result.exitCode == 0) {
        return result.stdout.toString();
      }
      return 'Error: ${result.stderr}';
    } catch (e) {
      return 'Error: $e';
    }
  }

  Future<String> convertImg(String src, String dst, {String? srcFormat, String dstFormat = 'qcow2'}) async {
    try {
      final args = ['convert'];
      if (srcFormat != null) {
        args.addAll(['-f', srcFormat]);
      }
      args.addAll(['-O', dstFormat, src, dst]);
      final result = await Process.run(qemuImgPath, args);
      if (result.exitCode == 0) {
        return result.stdout.toString();
      }
      return 'Error: ${result.stderr}';
    } catch (e) {
      return 'Error: $e';
    }
  }
}
