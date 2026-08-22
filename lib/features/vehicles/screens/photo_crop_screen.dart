import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:garage/l10n/app_localizations.dart';

/// Lets a household frame a picked photo before it uploads, rather than
/// sending whatever the camera happened to point at.
///
/// Pushed as its own screen rather than a dialog: a crop editor wants the
/// room a phone-sized dialog does not have, the same reason the tyre "add"
/// dialog needed fixing when the keyboard opened over it.
///
/// Pops with the cropped bytes, or `null` if the household backed out —
/// [ImageChooser] plumbs `null` back into "cancelled the pick" the same way a
/// closed file dialog already does, rather than falling back to the
/// uncropped original the household never chose to send.
class PhotoCropScreen extends StatefulWidget {
  const PhotoCropScreen({required this.image, super.key});

  final Uint8List image;

  @override
  State<PhotoCropScreen> createState() => _PhotoCropScreenState();
}

class _PhotoCropScreenState extends State<PhotoCropScreen> {
  final _controller = CropController();

  void _onCropped(CropResult result) {
    switch (result) {
      case CropSuccess(:final croppedImage):
        Navigator.of(context).pop(croppedImage);
      case CropFailure():
        // The pre-check in `isCroppableImage` is what keeps this screen from
        // ever opening on a file the codec cannot lay out in the first
        // place, so a failure here is the backend rejecting something
        // already on screen — nothing sent is better than a broken photo.
        Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.vehiclePhotoCropTitle),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: l10n.commonCancel,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _controller.crop,
            tooltip: l10n.commonSave,
          ),
        ],
      ),
      body: Crop(
        image: widget.image,
        controller: _controller,
        aspectRatio: 3 / 2,
        interactive: true,
        onCropped: _onCropped,
      ),
    );
  }
}
