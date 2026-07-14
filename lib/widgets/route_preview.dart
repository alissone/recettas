import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/gps_point.dart';

/// Miniature route thumbnail: the track's lat/lng points scaled to fit
/// the widget, with green/red dots marking start and end. Used both as
/// a small card thumbnail and, at a larger size, in the detail dialog.
class RoutePreview extends StatelessWidget {
  final List<GpsLatLng> points;
  final double size;

  const RoutePreview({super.key, required this.points, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusXSmall),
      child: Container(
        width: size,
        height: size,
        color: AppTheme.lightPeach,
        child: points.length < 2
            ? Icon(
                Icons.route_outlined,
                color: AppTheme.mediumBrown.withValues(alpha: 0.35),
                size: size * 0.4,
              )
            : CustomPaint(
                size: Size(size, size),
                painter: _RoutePainter(points: points),
              ),
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  final List<GpsLatLng> points;

  _RoutePainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    var minLat = points.first.lat, maxLat = points.first.lat;
    var minLng = points.first.lng, maxLng = points.first.lng;
    for (final p in points) {
      if (p.lat < minLat) minLat = p.lat;
      if (p.lat > maxLat) maxLat = p.lat;
      if (p.lng < minLng) minLng = p.lng;
      if (p.lng > maxLng) maxLng = p.lng;
    }

    const padding = 6.0;
    // A track that barely moves (or is a single point repeated) would
    // divide by zero below without this floor.
    final spanLat = math.max(maxLat - minLat, 1e-6);
    final spanLng = math.max(maxLng - minLng, 1e-6);
    final availW = size.width - padding * 2;
    final availH = size.height - padding * 2;
    final scale = math.min(availW / spanLng, availH / spanLat);
    final offsetX = padding + (availW - spanLng * scale) / 2;
    final offsetY = padding + (availH - spanLat * scale) / 2;

    Offset project(GpsLatLng p) => Offset(
          offsetX + (p.lng - minLng) * scale,
          // Latitude increases northward but canvas y increases downward.
          offsetY + (maxLat - p.lat) * scale,
        );

    final start = project(points.first);
    final path = Path()..moveTo(start.dx, start.dy);
    for (final p in points.skip(1)) {
      final o = project(p);
      path.lineTo(o.dx, o.dy);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = AppTheme.primaryOrange
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(start, 3, Paint()..color = Colors.green.shade500);
    canvas.drawCircle(project(points.last), 3, Paint()..color = Colors.red.shade400);
  }

  @override
  bool shouldRepaint(_RoutePainter oldDelegate) => oldDelegate.points != points;
}
