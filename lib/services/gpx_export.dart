import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/gps_point.dart';
import '../models/gps_recording.dart';

/// Builds a GPX 1.1 track file from a recording and hands it off to the
/// platform: a native share sheet on Android/iOS/macOS/modern Windows,
/// or a "reveal in file manager" fallback where file sharing isn't
/// available (Linux, older Windows).
class GpxExport {
  GpxExport._();

  static String _escape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  static String buildGpx(GpsRecording recording, List<GpsPoint> points) {
    final name = 'Gravação ${recording.startedAt.toIso8601String()}';
    final buffer = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln('<gpx version="1.1" creator="Recettas" '
          'xmlns="http://www.topografix.com/GPX/1/1">')
      ..writeln('  <trk>')
      ..writeln('    <name>${_escape(name)}</name>')
      ..writeln('    <trkseg>');
    for (final p in points) {
      buffer.writeln('      <trkpt lat="${p.lat}" lon="${p.lng}">');
      if (p.altitude != null) {
        buffer.writeln('        <ele>${p.altitude}</ele>');
      }
      buffer
          .writeln('        <time>${p.timestamp.toUtc().toIso8601String()}</time>');
      buffer.writeln('      </trkpt>');
    }
    buffer
      ..writeln('    </trkseg>')
      ..writeln('  </trk>')
      ..writeln('</gpx>');
    return buffer.toString();
  }

  static String _fileName(GpsRecording recording) {
    final d = recording.startedAt;
    String two(int n) => n.toString().padLeft(2, '0');
    return 'gravacao_${d.year}${two(d.month)}${two(d.day)}_'
        '${two(d.hour)}${two(d.minute)}.gpx';
  }

  static Future<void> export(GpsRecording recording, List<GpsPoint> points) async {
    final content = buildGpx(recording, points);
    final fileName = _fileName(recording);
    final dir = (Platform.isAndroid || Platform.isIOS)
        ? await getTemporaryDirectory()
        : await getApplicationDocumentsDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsString(content);

    try {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], fileNameOverrides: [fileName]),
      );
    } on UnimplementedError {
      // Linux (and pre-1809 Windows) have no native file share sheet.
      await _revealInFileManager(file);
    }
  }

  static Future<void> _revealInFileManager(File file) async {
    if (Platform.isWindows) {
      await Process.run('explorer', ['/select,${file.path}']);
    } else if (Platform.isMacOS) {
      await Process.run('open', ['-R', file.path]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [file.parent.path]);
    }
  }
}
