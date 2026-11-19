import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kosfinder_device_demo/main.dart';
import 'package:kosfinder_device_demo/services/draft_repository.dart';

// Smoke test ringan tanpa memerlukan kamera/GPS/Supabase di runner test.
void main() {
  test('App root is a MaterialApp widget', () {
    const app = KosFinderDeviceApp();
    expect(app, isA<StatelessWidget>());
  });

  group('DraftRepository safe path validation', () {
    test('allows file inside managed photo directory', () {
      expect(
        DraftRepository.isPathInsideDirectory(
          '/data/user/0/app/app_flutter/kosfinder_photos/12345.jpg',
          '/data/user/0/app/app_flutter/kosfinder_photos',
        ),
        isTrue,
      );
    });

    test('rejects file outside managed directory or traversal path', () {
      expect(
        DraftRepository.isPathInsideDirectory(
          '/data/user/0/app/app_flutter/kosfinder_photos/../secret.txt',
          '/data/user/0/app/app_flutter/kosfinder_photos',
        ),
        isFalse,
      );
      expect(
        DraftRepository.isPathInsideDirectory(
          '/storage/emulated/0/DCIM/Camera/photo.jpg',
          '/data/user/0/app/app_flutter/kosfinder_photos',
        ),
        isFalse,
      );
    });
  });
}
