import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/garage_theme.dart';

/// A vehicle's photo, or the fallback icon when it has none or the link has
/// gone stale.
///
/// Cached by [vehicleId] rather than by [url]: the link is signed and a fresh
/// one is minted on every fetch, so caching by URL would never hit and the
/// same few hundred KB would download on every visit to every screen that
/// shows it. Call [evictCache] right after a replacement upload — the id
/// alone can't tell a new photo from the one already on disk.
class VehiclePhoto extends StatelessWidget {
  const VehiclePhoto({
    required this.vehicleId,
    required this.url,
    required this.width,
    required this.height,
    this.borderRadius,
    super.key,
  });

  final String vehicleId;
  final Uri? url;
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  static Future<void> evictCache(String vehicleId) =>
      CachedNetworkImage.evictFromCache(vehicleId, cacheKey: vehicleId);

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(
      Icons.directions_car_outlined,
      color: context.tokens.muted,
    );
    final url = this.url;
    if (url == null) {
      return fallback;
    }
    final image = CachedNetworkImage(
      imageUrl: url.toString(),
      cacheKey: vehicleId,
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorWidget: (context, _, _) => fallback,
    );
    return borderRadius == null
        ? image
        : ClipRRect(borderRadius: borderRadius!, child: image);
  }
}
