import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../auth/service/auth_service.dart';

class AuthenticatedAttachmentImageLoader {
  AuthenticatedAttachmentImageLoader({
    ApiClient? apiClient,
    AuthService? authService,
  }) : _apiClient = apiClient ?? ApiClient(),
       _authService = authService ?? AuthService();

  final ApiClient _apiClient;
  final AuthService _authService;

  Future<Uint8List> load(String path) async {
    final bytes = await _authService.runWithAccessToken(
      (accessToken) => _apiClient.getBytes(path, accessToken: accessToken),
    );
    return bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  }
}

class AuthenticatedAttachmentImage extends StatefulWidget {
  const AuthenticatedAttachmentImage({
    super.key,
    required this.path,
    this.loader,
    this.fit = BoxFit.cover,
    this.loadingBuilder,
    this.errorBuilder,
  });

  final String path;
  final AuthenticatedAttachmentImageLoader? loader;
  final BoxFit fit;
  final WidgetBuilder? loadingBuilder;
  final WidgetBuilder? errorBuilder;

  @override
  State<AuthenticatedAttachmentImage> createState() =>
      _AuthenticatedAttachmentImageState();
}

class _AuthenticatedAttachmentImageState
    extends State<AuthenticatedAttachmentImage> {
  late AuthenticatedAttachmentImageLoader _loader;
  late Future<_LoadedAttachmentImage> _image;

  @override
  void initState() {
    super.initState();
    _loader = widget.loader ?? AuthenticatedAttachmentImageLoader();
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant AuthenticatedAttachmentImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path || oldWidget.loader != widget.loader) {
      _loader = widget.loader ?? AuthenticatedAttachmentImageLoader();
      _loadImage();
    }
  }

  void _loadImage() {
    _image = _loader.load(widget.path).then(_LoadedAttachmentImage.new);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_LoadedAttachmentImage>(
      future: _image,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return widget.loadingBuilder?.call(context) ??
              const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        final image = snapshot.data;
        if (snapshot.hasError || image == null || image.bytes.isEmpty) {
          return widget.errorBuilder?.call(context) ??
              const Center(child: Icon(Icons.image_not_supported_outlined));
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final pixelRatio = MediaQuery.devicePixelRatioOf(context);
            final cacheWidth = _cacheDimension(
              constraints.maxWidth,
              pixelRatio,
            );
            final cacheHeight = _cacheDimension(
              constraints.maxHeight,
              pixelRatio,
            );
            return Image(
              image: ResizeImage.resizeIfNeeded(
                cacheWidth,
                cacheHeight,
                image.provider,
              ),
              fit: widget.fit,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) =>
                  widget.errorBuilder?.call(context) ??
                  const Center(child: Icon(Icons.image_not_supported_outlined)),
            );
          },
        );
      },
    );
  }

  int? _cacheDimension(double logicalPixels, double pixelRatio) {
    if (!logicalPixels.isFinite || logicalPixels <= 0) return null;
    return (logicalPixels * pixelRatio).ceil();
  }
}

class _LoadedAttachmentImage {
  _LoadedAttachmentImage(this.bytes) : provider = MemoryImage(bytes);

  final Uint8List bytes;
  final MemoryImage provider;
}
