import 'dart:io';
import 'dart:math';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../core/categories.dart';
import '../models/ocr_result.dart';
import 'receipt_parser.dart';

/// Hợp đồng của lớp OCR (IReceiptCapture trong component diagram).
///
/// UI chỉ phụ thuộc vào interface này, nên đổi giữa [MlKitOcrService] và
/// [StubOcrService] không phải sửa View hay ViewModel.
abstract class OcrService {
  Future<OcrResult> extract(File image);
}

/// Nhận dạng chữ on-device bằng ML Kit (ảnh không rời khỏi thiết bị).
///
/// Ảnh đầu vào nên là ảnh đã được `cunning_document_scanner` cắt và nắn
/// phối cảnh, để các dòng chữ thẳng hàng - [ReceiptParser] dựa vào toạ độ
/// dòng để ghép nhãn "TOTAL" với số tiền cùng hàng.
class MlKitOcrService implements OcrService {
  MlKitOcrService({ReceiptParser? parser})
      : _parser = parser ?? ReceiptParser();

  final ReceiptParser _parser;

  /// Model Latin đủ cho hoá đơn tiếng Anh; tạo một lần và dùng suốt vòng đời
  /// app vì TransactionViewModel cũng sống suốt vòng đời app.
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

/// Cài đặt giả lập, dùng cho test và máy không chạy được ML Kit
/// (vd. simulator).
///
/// Trả về dữ liệu có cấu trúc giống hệt kết quả ML Kit thật (kèm confidence
/// từng trường) để màn hình Review hoạt động đầy đủ mà chưa cần native plugin.
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
    // Mô phỏng thời gian chạy inference on-device (yêu cầu < 2s, mục 1.2.1).
    await Future<void>.delayed(const Duration(milliseconds: 900));

    final s = _samples[_random.nextInt(_samples.length)];

    // Một trường ngẫu nhiên sẽ có confidence thấp, để minh hoạ luồng sửa lỗi
    // được mô tả ở mục 5.4 của báo cáo.
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
