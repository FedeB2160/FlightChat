// lib/features/onboarding/presentation/widgets/qr_scanner_widget.dart — Camera QR scanner view with viewfinder overlay
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/theme/app_colors.dart';

class QrScannerWidget extends StatefulWidget {
  final Function(String) onScan;

  const QrScannerWidget({super.key, required this.onScan});

  @override
  State<QrScannerWidget> createState() => _QrScannerWidgetState();
}

class _QrScannerWidgetState extends State<QrScannerWidget> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: (capture) {
            if (_isProcessing) return;
            final List<Barcode> barcodes = capture.barcodes;
            for (final barcode in barcodes) {
              if (barcode.rawValue != null) {
                _isProcessing = true;
                widget.onScan(barcode.rawValue!);
                Future.delayed(const Duration(seconds: 2), () {
                  if (mounted) {
                    _isProcessing = false;
                  }
                });
                break;
              }
            }
          },
        ),
        Container(
          width: 250,
          height: 250,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.primary, width: 3),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.5),
                blurRadius: 20,
                spreadRadius: 2,
              )
            ],
          ),
        ),
      ],
    );
  }
}
