import 'dart:io';
import 'dart:math';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../core/categories.dart';
import '../models/ocr_result.dart';
import 'receipt_parser.dart';

/// Contract for the OCR layer (IReceiptCapture in the component diagram).
///
/// The UI depends only on this interface, so switching between [MlKitOcrService] and
/// [StubOcrService] requires no changes to Views or ViewModels.
abstract class OcrService {
  Future<OcrResult> extract(File image);
}

/// On-device text recognition with ML Kit (the image never leaves the device).
///
/// The input image should already be cropped and perspective-corrected by
/// `cunning_document_scanner` so text lines are aligned - [ReceiptParser] relies on line
/// coordinates to pair the "TOTAL" label with the amount on the same row.
class MlKitOcrService implements OcrService {
  MlKitOcrService({ReceiptParser? parser})
      : _parser = parser ?? ReceiptParser();

  final ReceiptParser _parser;

  /// The Latin model is enough for English receipts; create it once and keep it for the
  /// app's lifetime since TransactionViewModel also lives for the app's lifetime.
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  @override
  Future<OcrResult> extract(File image) async {
    final recognized =
        await _recognizer.processImage(InputImage.fromFilePath(image.path));

    final lines = [
      for (final block in recognized.blocks)
        for (final line in block.lines)
          ReceiptLine(line.text, line.boundingBox, confidence: line.confidence),
    ];
    if (lines.isEmpty) {
      throw StateError('No text found on the receipt image.');
    }
    return _parser.parse(lines, imagePath: image.path);
  }

  Future<void> close() => _recognizer.close();
}

/// Fake implementation, used for tests and devices that cannot run ML Kit
/// (vd. simulator).
///
/// Returns data with exactly the same structure as real ML Kit output (with per-field
/// confidence) so the Review screen works fully without the native plugin.
class StubOcrService implements OcrService {
  StubOcrService({Random? random}) : _random = random ?? Random();

  final Random _random;

  static const _samples = <Map<String, Object>>[
    {
      'merchant': 'New World Victoria St',
      'amount': 54.20,
      'category': Categories.groceries,
    },
    {
      'merchant': 'Z Energy Symonds St',
      'amount': 61.00,
      'category': Categories.transport,
    },
    {
      'merchant': 'Coffee Club',
      'amount': 5.50,
      'category': Categories.eatingOut,
    },
    {
      'merchant': 'Countdown Metro',
      'amount': 32.75,
      'category': Categories.groceries,
    },
    {
      'merchant': 'Mercury Energy',
      'amount': 118.40,
      'category': Categories.utilities,
    },
  ];

  @override
  Future<OcrResult> extract(File image) async {
    // Simulate on-device inference time (requirement < 2s, section 1.2.1).
    await Future<void>.delayed(const Duration(milliseconds: 900));

    final s = _samples[_random.nextInt(_samples.length)];

    // One random field gets low confidence, to demonstrate the correction flow
    // described in section 5.4 of the report.
    final weakIndex = _random.nextInt(4);
    double conf(int index) => index == weakIndex
        ? 0.55 + _random.nextDouble() * 0.15
        : 0.90 + _random.nextDouble() * 0.09;

    return OcrResult(
      merchant: OcrField(s['merchant'] as String, conf(0)),
      amount: OcrField(s['amount'] as double, conf(1)),
      date: OcrField(
        DateTime.now().subtract(Duration(days: _random.nextInt(3))),
        conf(2),
      ),
      category: OcrField(s['category'] as String, conf(3)),
      imagePath: image.path,
    );
  }
}
