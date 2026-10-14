import 'dart:async';
import 'package:zivlo/injection_container.dart';
import 'package:zivlo/features/scanner/domain/entities/scan_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:zivlo/core/theme/app_theme.dart';
import 'package:zivlo/features/scanner/infrastructure/adapters/mobile_scanner_adapter.dart';
import 'package:zivlo/features/scanner/presentation/bloc/scanner_bloc.dart';
import 'package:zivlo/features/scanner/presentation/bloc/scanner_event.dart';
import 'package:zivlo/features/scanner/presentation/bloc/scanner_state.dart';
import 'package:zivlo/features/scanner/presentation/widgets/scanner_overlay.dart';
import 'package:zivlo/features/scanner/presentation/widgets/scan_result_bottom_sheet.dart';
import 'package:zivlo/features/scanner/presentation/widgets/product_not_found_dialog.dart';
/// Scanner Page
/// Full-screen barcode scanning page with camera view
///
/// Features:
/// - Full-screen camera preview
/// - Scanner overlay with guide area
/// - Close button (top-left)
/// - Flash toggle button (bottom-left)
/// - Product found bottom sheet
/// - Product not found dialog
class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  late final ScannerBloc _scannerBloc;
  late final MobileScannerController _cameraController;

  @override
  void initState() {
    super.initState();

    _scannerBloc = sl<ScannerBloc>();
    _cameraController = (_scannerBloc.scannerPort as MobileScannerAdapter).controller;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scannerBloc.add(const ScannerStarted());
    });
  }

  @override
  void dispose() {
    unawaited(_scannerBloc.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _scannerBloc,
      child: Scaffold(
        backgroundColor: AppColors.colorBackground,
        body: Stack(
          children: [
            _buildScannerListener(),
            // Camera preview (full-screen)
            Positioned.fill(
              child: MobileScanner(
                controller: _cameraController,
                errorBuilder: (context, error, child) {
                  return _buildErrorWidget(error);
                },
              ),
            ),

            // Scanner overlay with guide area
            const ScannerOverlay(),

            // Close button (top-left)
            Positioned(
              top: AppSpacing.spacing16,
              left: AppSpacing.spacing16,
              child: SafeArea(
                child: IconButton(
                  onPressed: () {
                    _scannerBloc.add(const ScannerStopped());
                    context.pop();
                  },
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.colorSurface.withOpacity(0.8),
                    foregroundColor: AppColors.colorOnSurface,
                    minimumSize: const Size(48, 48),
                  ),
                ),
              ),
            ),

            // Flash toggle button (bottom-left)
            Positioned(
              bottom: AppSpacing.spacing24,
              left: AppSpacing.spacing24,
              child: SafeArea(
                child: BlocBuilder<ScannerBloc, ScannerState>(
                  builder: (context, state) {
                    final isFlashOn = state is ScannerFlashEnabled;

                    return IconButton(
                      onPressed: () {
                        _scannerBloc.add(FlashToggled(!isFlashOn));
                      },
                      icon: Icon(
                        isFlashOn ? Icons.flash_on : Icons.flash_off,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.colorSurface.withOpacity(0.8),
                        foregroundColor: AppColors.colorOnSurface,
                        minimumSize: const Size(56, 56),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// BlocListener for handling state changes
  Widget _buildScannerListener() {
    return BlocListener<ScannerBloc, ScannerState>(
      listener: (context, state) {
        if (state is ScannerProductFound) {
          // Show product found bottom sheet
          _showProductFoundBottomSheet(state.result);
        } else if (state is ScannerProductNotFound) {
          // Show product not found dialog
          _showProductNotFoundDialog(state.barcode);
        } else if (state is ScannerCartUpdated) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${state.quantity} × ${state.productName} agregado al carrito'),
          ));
        } else if (state is ScannerErrorState) {
          // Show error snackbar
          _showErrorSnackbar(state.message);
        }
      },
      child: const SizedBox.shrink(),
    );
  }

  /// Show product found bottom sheet
  Future<void> _showProductFoundBottomSheet(ScanResult result) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return BlocProvider.value(
          value: _scannerBloc,
          child: ScanResultBottomSheet(
            result: result,
            onContinueScanning: () => Navigator.pop(context),
          ),
        );
      },
    );
    if (mounted) _scannerBloc.add(const ScannerStarted());
  }

  /// Show product not found dialog
  Future<void> _showProductNotFoundDialog(String barcode) async {
    await showDialog(
      context: context,
      builder: (context) {
        return ProductNotFoundDialog(barcode: barcode);
      },
    );
    if (mounted) _scannerBloc.add(const ScannerStarted());
  }

  /// Show error snackbar
  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.colorError,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
        ),
      ),
    );
  }

  /// Build error widget for camera errors
  Widget _buildErrorWidget(MobileScannerException error) {
    return Container(
      color: AppColors.colorBackground,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.no_photography,
              size: 64,
              color: AppColors.colorError,
            ),
            const SizedBox(height: AppSpacing.spacing24),
            Text(
              'Error de cámara',
              style: AppTypography.textTheme.headlineMedium?.copyWith(
                color: AppColors.colorOnSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.spacing8),
            Text(
              error.errorDetails?.message ?? 'No se pudo acceder a la cámara',
              style: AppTypography.textTheme.bodyMedium?.copyWith(
                color: AppColors.colorOnSurfaceMuted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.spacing24),
            ElevatedButton(
              onPressed: () {
                context.pop();
              },
              child: const Text('Volver'),
            ),
          ],
        ),
      ),
    );
  }
}
