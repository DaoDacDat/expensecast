import 'dart:io';

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/transaction_view_model.dart';
import 'review_view.dart';

/// Mockup 3: Receipt Capture.
///
/// Mở trình quét tài liệu native (ML Kit trên Android, VisionKit trên iOS):
/// nó tự dò mép hoá đơn, cắt và nắn phối cảnh, rồi trả về ảnh đã phẳng.
/// Ảnh đó đi thẳng vào OCR on-device và sang màn hình Review - không rời
/// khỏi thiết bị.
class CaptureView extends StatefulWidget {
  const CaptureView({super.key});

  @override
  State<CaptureView> createState() => _CaptureViewState();
}

enum _Phase { scanning, reading, failed }

class _CaptureViewState extends State<CaptureView> {
  _Phase _phase = _Phase.scanning;
  String? _error;
  bool _scannerOpen = false;

  @override
  void initState() {
    super.initState();
    // Mở scanner ngay khi vào màn hình, sau frame đầu để có context hợp lệ.
    WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
  }

  Future<void> _scan(
      [ScannerSource source = ScannerSource.cameraAndGallery]) async {
    if (_scannerOpen) return;
    _scannerOpen = true;
    setState(() {
      _phase = _Phase.scanning;
      _error = null;
    });

    List<String>? pages;
    try {
      pages = await CunningDocumentScanner.getPictures(
        noOfPages: 1,
        scannerSource: source,
        // PNG mặc định rất nặng; JPEG 90% vẫn đủ nét cho OCR.
        iosScannerOptions: IosScannerOptions(
          imageFormat: IosImageFormat.jpg,
          jpgCompressionQuality: 0.9,
        ),
      );
    } on CunningDocumentScannerException catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.failed;
        _error = e.code == 'permission_denied'
            ? 'Camera permission was denied. Enable it in Settings to scan '
                'receipts, or choose a photo instead.'
            : 'Could not open the scanner (${e.code ?? 'unknown error'}).';
      });
      return;
    } finally {
      _scannerOpen = false;
    }

    if (!mounted) return;
    if (pages == null) {
      // Người dùng huỷ trong scanner -> quay lại màn trước.
      Navigator.of(context).pop(false);
      return;
    }
    await _readAndReview(File(pages.first));
  }

  /// Bước 1.1 -> 2 trong sequence diagram: OCR xong thì mở màn hình Review.
  Future<void> _readAndReview(File image) async {
    setState(() => _phase = _Phase.reading);

    final vm = context.read<TransactionViewModel>();
    final ok = await vm.addFromReceipt(image);

    if (!mounted) return;
    if (!ok) {
      await _cleanScans();
      if (!mounted) return;
      setState(() {
        _phase = _Phase.failed;
        _error = vm.error ?? 'Could not read this receipt.';
      });
      return;
    }

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ReviewView(imageFile: image)),
    );
    await _cleanScans();

    if (!mounted) return;
    if (saved == true) {
      Navigator.of(context).pop(true);
    } else {
      // Bỏ bản nháp ở Review = muốn chụp lại.
      await _scan();
    }
  }

  /// Giao dịch không lưu ảnh, nên xoá ảnh quét ngay sau khi dùng xong
  /// (trên Android thư mục của plugin không tự dọn).
  Future<void> _cleanScans() async {
    try {
      await CunningDocumentScanner.cleanCache();
    } on CunningDocumentScannerException {
      // Không ảnh hưởng luồng chính; hệ điều hành sẽ dọn sau.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan receipt'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Cancel',
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: Center(child: _buildStatus())),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 14, 24, 28),
              child: Text(
                'On-device OCR · image never uploaded',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 12.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatus() {
    return switch (_phase) {
      _Phase.scanning => const _Progress('Opening scanner…'),
      _Phase.reading => const _Progress('Reading receipt on this device…'),
      _Phase.failed => Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_outlined,
                  color: Colors.white70, size: 44),
              const SizedBox(height: 16),
              Text(
                _error ?? 'Something went wrong.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, height: 1.4),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _scan,
                icon: const Icon(Icons.document_scanner_outlined),
                label: const Text('Scan again'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                ),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () => _scan(ScannerSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Choose a photo instead'),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
    };
  }
}

class _Progress extends StatelessWidget {
  const _Progress(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(color: Colors.white),
        const SizedBox(height: 14),
        Text(label, style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}
