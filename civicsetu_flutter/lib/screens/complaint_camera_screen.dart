import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../localization.dart';
import '../models.dart';
import '../utils/location_service.dart';

class ComplaintCameraResult {
  const ComplaintCameraResult({
    required this.imagePath,
    required this.locationDraft,
  });

  final String imagePath;
  final LocationDraft? locationDraft;
}

class ComplaintCameraScreen extends StatefulWidget {
  const ComplaintCameraScreen({super.key, required this.l10n});

  final AppLocalizations l10n;

  @override
  State<ComplaintCameraScreen> createState() => _ComplaintCameraScreenState();
}

class _ComplaintCameraScreenState extends State<ComplaintCameraScreen> {
  CameraController? _controller;
  bool _cameraReady = false;
  bool _capturing = false;
  bool _detectingLocation = false;
  String? _errorMessage;
  LocationDraft? _locationDraft;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _refreshLocation();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 18,
                          color: Color(0xFF34D399),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.l10n.t('camera.geoFetchAlwaysOn'),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: ColoredBox(
                    color: const Color(0xFF0F172A),
                    child: _buildPreview(),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              child: Column(
                children: [
                  if (_detectingLocation)
                    Text(
                      widget.l10n.t('camera.detectingLocation'),
                      style: const TextStyle(color: Colors.white70),
                    )
                  else if (_locationDraft != null)
                    Text(
                      '${widget.l10n.t('camera.locationReady')}: ${_locationDraft!.city.isEmpty ? _locationDraft!.latitude.toStringAsFixed(4) : _locationDraft!.city}',
                      style: const TextStyle(color: Color(0xFF86EFAC)),
                      textAlign: TextAlign.center,
                    )
                  else if (_errorMessage != null)
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Color(0xFFFDA4AF)),
                      textAlign: TextAlign.center,
                    )
                  else
                    Text(
                      widget.l10n.t('camera.captureHelp'),
                      style: const TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _refreshLocation,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white24),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: const Icon(Icons.my_location_rounded),
                          label: Text(widget.l10n.t('camera.refreshLocation')),
                        ),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: _cameraReady && !_capturing ? _capture : null,
                        child: Container(
                          width: 82,
                          height: 82,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white70, width: 3),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _capturing
                                  ? const Color(0xFFF59E0B)
                                  : Colors.white,
                            ),
                            alignment: Alignment.center,
                            child: _capturing
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: Color(0xFF0B1C2D),
                                    ),
                                  )
                                : const Icon(
                                    Icons.camera_rounded,
                                    color: Color(0xFF0B1C2D),
                                    size: 32,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    if (_errorMessage != null && !_cameraReady) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (!_cameraReady || _controller == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 16),
            Text(
              widget.l10n.t('camera.initializing'),
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(_controller!),
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white24, width: 1.5),
              borderRadius: BorderRadius.circular(28),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception(widget.l10n.t('camera.unavailable'));
      }
      final preferred = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        preferred,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _cameraReady = true;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = widget.l10n.t('camera.unavailable');
      });
    }
  }

  Future<void> _refreshLocation() async {
    setState(() {
      _detectingLocation = true;
      _errorMessage = null;
    });
    try {
      final draft = await resolveCurrentLocation(
        permissionDeniedMessage: widget.l10n.t('msg.permissionDenied'),
        locationUnavailableMessage: widget.l10n.t('msg.locationUnavailable'),
        serviceDisabledMessage: widget.l10n.t('msg.locationServiceDisabled'),
        userAgent: 'com.civicsetu.mobile.camera',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _locationDraft = draft;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = '$error';
      });
    } finally {
      if (mounted) {
        setState(() => _detectingLocation = false);
      }
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    setState(() => _capturing = true);
    try {
      if (_locationDraft == null) {
        await _refreshLocation();
      }
      final file = await controller.takePicture();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(
        ComplaintCameraResult(
          imagePath: file.path,
          locationDraft: _locationDraft,
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.l10n.t('camera.captureFailed'))),
      );
    } finally {
      if (mounted) {
        setState(() => _capturing = false);
      }
    }
  }
}
