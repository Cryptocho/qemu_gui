import 'package:flutter_test/flutter_test.dart';
import 'package:qemu_gui/models/shared_folder.dart';

void main() {
  group('generateMountTag', () {
    test('collapses spaces in basename to underscores', () {
      expect(SharedFolder.generateMountTag('/home/u/My Docs', []), 'My_Docs');
    });

    test('prefixes tags that do not start with a letter', () {
      expect(SharedFolder.generateMountTag('/x/2024', []), 'share_2024');
    });

    test('dedupes against taken tags', () {
      expect(SharedFolder.generateMountTag('/a/iso', ['iso']), 'iso_2');
      expect(SharedFolder.generateMountTag('/a/iso', ['iso', 'iso_2']), 'iso_3');
    });

    test('falls back to share when nothing usable remains', () {
      expect(SharedFolder.generateMountTag('/', []), 'share');
    });
  });

  group('sanitizeMountTag', () {
    test('keeps valid ids untouched', () {
      expect(SharedFolder.sanitizeMountTag('My_Photos.v2'), 'My_Photos.v2');
    });

    test('prefixes dot-prefixed names', () {
      expect(SharedFolder.sanitizeMountTag('.hidden'), 'share_.hidden');
    });

    test('returns share for names without alphanumerics', () {
      expect(SharedFolder.sanitizeMountTag('___'), 'share');
      expect(SharedFolder.sanitizeMountTag(''), 'share');
    });
  });

  group('isValidMountTag', () {
    test('accepts letter-started ids from the QEMU charset', () {
      expect(SharedFolder.isValidMountTag('My_Docs'), isTrue);
      expect(SharedFolder.isValidMountTag('My_Photos.v2'), isTrue);
      expect(SharedFolder.isValidMountTag('iso_2'), isTrue);
    });

    test('rejects ids QEMU would refuse', () {
      expect(SharedFolder.isValidMountTag('2024share'), isFalse); // digit start
      expect(SharedFolder.isValidMountTag('_x'), isFalse); // underscore start
      expect(SharedFolder.isValidMountTag('.hidden'), isFalse); // dot start
      expect(SharedFolder.isValidMountTag('my share'), isFalse); // space
      expect(SharedFolder.isValidMountTag('a,b'), isFalse); // comma
      expect(SharedFolder.isValidMountTag(''), isFalse); // empty
    });
  });

  group('json roundtrip', () {
    test('preserves path, tag and readOnly', () {
      final folder = SharedFolder(path: '/home/u/My Docs', mountTag: 'My_Docs', readOnly: true);
      final restored = SharedFolder.fromJson(folder.toJson());
      expect(restored.path, folder.path);
      expect(restored.mountTag, folder.mountTag);
      expect(restored.readOnly, folder.readOnly);
    });

    test('legacy entry without mountTag derives it from path', () {
      final legacy = SharedFolder.fromJson({'path': '/a/b'});
      expect(legacy.mountTag, 'b');
      expect(legacy.readOnly, false);
    });
  });
}
