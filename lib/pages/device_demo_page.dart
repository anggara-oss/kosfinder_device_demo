import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../cloud_config.dart';
import '../services/device_location_service.dart';
import '../services/draft_repository.dart';
import '../services/photo_upload_service.dart';
import 'sensor_demo_page.dart';

class DeviceDemoPage extends StatefulWidget {
  const DeviceDemoPage({super.key});

  @override
  State<DeviceDemoPage> createState() => _DeviceDemoPageState();
}

class _DeviceDemoPageState extends State<DeviceDemoPage> {
  final _nameController = TextEditingController();
  final _picker = ImagePicker();
  final _drafts = DraftRepository();
  final _location = DeviceLocationService();
  final _uploader = PhotoUploadService();

  String? _photoPath;
  String? _storagePath;
  String? _publicUrl;
  double? _latitude;
  double? _longitude;
  LocationFailureType? _locationError;
  bool _busy = false;

  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _border = Color(0xFFE2E8F0);
  static const _primary = Color(0xFF0F766E);

  @override
  void initState() {
    super.initState();
    _restoreLocalDraft();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _restoreLocalDraft() async {
    try {
      final draft = await _drafts.load();
      if (!mounted) return;
      setState(() {
        _nameController.text = draft['name'] as String? ?? '';
        _photoPath = draft['photoPath'] as String?;
        _storagePath = draft['storagePath'] as String?;
        _publicUrl = draft['publicUrl'] as String?;
        final lat = draft['latitude'];
        final lng = draft['longitude'];
        _latitude = lat is num ? lat.toDouble() : null;
        _longitude = lng is num ? lng.toDouble() : null;
      });
      await _recoverInterruptedPicker();
    } catch (error) {
      _notice('Draft lokal belum dapat dibaca: $error');
    }
  }

  Future<void> _recoverInterruptedPicker() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final lost = await _picker.retrieveLostData();
    if (lost.isEmpty) return;
    if (lost.files != null && lost.files!.isNotEmpty) {
      await _acceptPhoto(lost.files!.first);
      _notice('Foto dari proses kamera/galeri yang terputus dipulihkan.');
    } else if (lost.exception != null) {
      _notice('Pemulihan foto gagal: ${lost.exception}');
    }
  }

  Future<void> _saveDraft({bool showMessage = true}) async {
    await _drafts.save({
      'name': _nameController.text.trim(),
      'photoPath': _photoPath,
      'latitude': _latitude,
      'longitude': _longitude,
      'storagePath': _storagePath,
      'publicUrl': _publicUrl,
    });
    if (showMessage) _notice('Draft berhasil disimpan di perangkat.');
  }

  Future<void> _acceptPhoto(XFile picked) async {
    final previousPath = _photoPath;
    final permanentPath = await _drafts.savePermanentPhoto(picked);
    if (previousPath != null && previousPath != permanentPath) {
      try {
        await _drafts.deleteSafeLocalPhoto(previousPath);
      } catch (_) {
        // Jangan gagalkan pemilihan foto baru jika pembersihan foto lama gagal.
      }
    }
    if (!mounted) return;
    setState(() {
      _photoPath = permanentPath;
      _storagePath = null;
      _publicUrl = null;
    });
    await _saveDraft(showMessage: false);
  }

  Future<void> _confirmDeletePhoto() async {
    if (_busy || _photoPath == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Hapus Foto Lokal?'),
        content: const Text(
          'Foto yang tersimpan di penyimpanan aplikasi akan dihapus secara aman '
          'dan draft lokal akan diperbarui.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(88, 40),
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await _drafts.deleteSafeLocalPhoto(_photoPath);
      if (!mounted) return;
      setState(() {
        _photoPath = null;
        _storagePath = null;
        _publicUrl = null;
      });
      await _saveDraft(showMessage: false);
      _notice('Foto lokal berhasil dihapus dengan aman.');
    } catch (error) {
      _notice('Gagal menghapus foto lokal: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _choosePhoto(ImageSource source) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 80,
      );
      if (picked == null) {
        _notice('Pemilihan foto dibatalkan; draft tidak berubah.');
        return;
      }
      await _acceptPhoto(picked);
      _notice('Foto disalin ke penyimpanan permanen aplikasi.');
    } on PlatformException catch (error) {
      _notice('Kamera/galeri tidak tersedia (${error.code}). Cek izin perangkat.');
    } on FormatException catch (error) {
      _notice(error.message);
    } catch (error) {
      _notice('Gagal memilih foto: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _getLocation() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _locationError = null;
    });
    try {
      final position = await _location.getPosition();
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
      await _saveDraft(showMessage: false);
      _notice('Koordinat berhasil diambil dan tersimpan dalam draft.');
    } on LocationFailure catch (error) {
      if (!mounted) return;
      setState(() => _locationError = error.type);
      _notice(error.message);
    } on TimeoutException {
      _notice('Waktu mencari GPS habis. Coba dekat jendela/area terbuka.');
    } catch (error) {
      _notice('Lokasi tidak dapat diambil: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _upload() async {
    if (_busy || !CloudConfig.enabled) return;
    if (_nameController.text.trim().isEmpty) {
      _notice('Isi nama kos sebelum mengunggah foto.');
      return;
    }
    final path = _photoPath;
    if (path == null || !File(path).existsSync()) {
      _notice('Ambil/pilih foto terlebih dahulu.');
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await _uploader.upload(File(path));
      if (!mounted) return;
      setState(() {
        _storagePath = result.storagePath;
        _publicUrl = result.publicUrl;
      });
      await _saveDraft(showMessage: false);
      _notice('Berhasil! Foto tersedia pada Supabase Storage.');
    } on AuthException catch (error) {
      _notice('Login anonymous Supabase gagal: ${error.message}');
    } on StorageException catch (error) {
      _notice('Upload ditolak Storage: ${error.message}');
    } catch (error) {
      _notice('Gagal upload: $error. Draft lokal tetap ada.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photoExists =
        !kIsWeb && _photoPath != null && File(_photoPath!).existsSync();
    final hasCoordinates = _latitude != null && _longitude != null;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('KosFinder'),
            Text(
              'Device Integration Demo',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: _muted,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_busy ? 3 : 1),
          child: _busy
              ? const LinearProgressIndicator(minHeight: 3)
              : const Divider(height: 1, thickness: 1, color: _border),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: _primary,
                backgroundColor: _primary.withValues(alpha: 0.08),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SensorDemoPage()),
              ),
              icon: const Icon(Icons.sensors_rounded, size: 18),
              label: const Text(
                'Sensor',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            _ModeBanner(cloudEnabled: CloudConfig.enabled),
            const SizedBox(height: 14),
            _SectionCard(
              icon: Icons.home_work_outlined,
              title: 'Informasi & Foto Kos',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _nameController,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Nama kos',
                      hintText: 'Contoh: Kos Melati',
                      prefixIcon: Icon(Icons.badge_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (photoExists)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.file(
                            File(_photoPath!),
                            height: 210,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          left: 10,
                          bottom: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.62),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  'Tersimpan lokal',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Material(
                            color: Colors.black.withValues(alpha: 0.62),
                            shape: const CircleBorder(),
                            child: IconButton(
                              tooltip: 'Hapus foto lokal',
                              onPressed: _busy ? null : _confirmDeletePhoto,
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Container(
                      height: 164,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _border),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: Color(0xFFE2E8F0),
                            child: Icon(
                              Icons.add_a_photo_outlined,
                              color: Color(0xFF475569),
                              size: 22,
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Belum ada foto kamar',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _ink,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Format JPG / PNG · Maksimal 5 MB',
                            style: TextStyle(color: _muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _choosePhoto(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_outlined, size: 18),
                          label: const Text('Kamera'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _choosePhoto(ImageSource.gallery),
                          icon:
                              const Icon(Icons.photo_library_outlined, size: 18),
                          label: const Text('Galeri'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _SectionCard(
              icon: Icons.location_on_outlined,
              title: 'Koordinat Lokasi (GPS)',
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Opsional',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _muted,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _border),
                    ),
                    child: hasCoordinates
                        ? Row(
                            children: [
                              Expanded(
                                child: _CoordItem(
                                  label: 'Latitude',
                                  value: _latitude!.toStringAsFixed(6),
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 32,
                                color: _border,
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 12),
                                  child: _CoordItem(
                                    label: 'Longitude',
                                    value: _longitude!.toStringAsFixed(6),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : const Row(
                            children: [
                              Icon(
                                Icons.gps_not_fixed_rounded,
                                size: 18,
                                color: _muted,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Koordinat belum diisi',
                                style: TextStyle(color: _muted, fontSize: 13.5),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: _busy ? null : _getLocation,
                    icon: const Icon(Icons.my_location_rounded, size: 18),
                    label: const Text('Ambil Koordinat GPS'),
                  ),
                  if (_locationError == LocationFailureType.serviceDisabled) ...[
                    const SizedBox(height: 8),
                    _SettingsPrompt(
                      message: 'Layanan GPS perangkat sedang nonaktif.',
                      actionLabel: 'Buka pengaturan layanan lokasi',
                      onPressed: () => Geolocator.openLocationSettings(),
                    ),
                  ],
                  if (_locationError == LocationFailureType.deniedForever) ...[
                    const SizedBox(height: 8),
                    _SettingsPrompt(
                      message: 'Izin lokasi ditolak permanen untuk aplikasi ini.',
                      actionLabel: 'Buka pengaturan izin aplikasi',
                      onPressed: () => Geolocator.openAppSettings(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            _SectionCard(
              icon: Icons.inventory_2_outlined,
              title: 'Penyimpanan & Sinkronisasi',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : () async {
                            try {
                              await _saveDraft();
                            } catch (error) {
                              _notice('Gagal menyimpan draft: $error');
                            }
                          },
                    icon: const Icon(Icons.save_outlined, size: 19),
                    label: const Text('Simpan Draft Lokal'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _busy || !CloudConfig.enabled ? null : _upload,
                    icon: const Icon(Icons.cloud_upload_outlined, size: 19),
                    label: const Text('Upload Foto ke Supabase (opsional)'),
                  ),
                  if (!CloudConfig.enabled) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Mode lokal aktif. Jalankan dengan --dart-define untuk mengaktifkan upload Supabase.',
                      style: TextStyle(fontSize: 12, color: _muted),
                    ),
                  ],
                  if (_storagePath != null || _publicUrl != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDFA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _primary.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_storagePath != null) ...[
                            const Text(
                              'Lokasi objek Storage',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: _primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            SelectableText(
                              _storagePath!,
                              style: const TextStyle(fontSize: 12.5, color: _ink),
                            ),
                          ],
                          if (_publicUrl != null) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'URL foto publik',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: _primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            SelectableText(
                              _publicUrl!,
                              style: const TextStyle(fontSize: 12.5, color: _ink),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 17, color: _muted),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'GPS menunjukkan posisi ponsel, bukan otomatis posisi kos. '
                      'Jangan unggah foto orang atau informasi pribadi untuk demo.',
                      style: TextStyle(
                        fontSize: 12,
                        color: _muted,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeBanner extends StatelessWidget {
  const _ModeBanner({required this.cloudEnabled});

  final bool cloudEnabled;

  @override
  Widget build(BuildContext context) {
    final accent =
        cloudEnabled ? const Color(0xFF0F766E) : const Color(0xFF475569);
    final bg = cloudEnabled ? const Color(0xFFF0FDFA) : Colors.white;
    final border = cloudEnabled
        ? const Color(0xFF99F6E4)
        : const Color(0xFFE2E8F0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: cloudEnabled
                  ? const Color(0xFF10B981)
                  : const Color(0xFF64748B),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              cloudEnabled
                  ? 'Mode: lokal + Supabase (tanpa Worksheet 9)'
                  : 'Mode: lokal/offline (Supabase belum dikonfigurasi)',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 19, color: const Color(0xFF0F766E)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      );
}

class _CoordItem extends StatelessWidget {
  const _CoordItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      );
}

class _SettingsPrompt extends StatelessWidget {
  const _SettingsPrompt({
    required this.message,
    required this.actionLabel,
    required this.onPressed,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF92400E),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                foregroundColor: const Color(0xFFB45309),
              ),
              onPressed: onPressed,
              child: Text(
                actionLabel,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
}
