import 'dart:ui' show Rect;

import 'package:expensecast/core/categories.dart';
import 'package:expensecast/services/receipt_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds an OCR line at row [row], column [x] - mimicking how ML Kit splits
/// the label on the left and the amount on the right into two separate blocks.
ReceiptLine line(String text, int row, {double x = 20, double? conf}) =>
    ReceiptLine(
      text,
      Rect.fromLTWH(x, row * 40.0, text.length * 12.0, 30),
      confidence: conf,
    );

void main() {
  final parser = ReceiptParser(clock: () => DateTime(2026, 9, 25, 12));

  test('reads a supermarket receipt with the label and amount in two columns', () {
    final result = parser.parse([
      line('NEW WORLD VICTORIA ST', 0),
      line('GST No: 123-456-789', 1),
      line('Date: 18/09/2026 14:02', 2),
      line('MILK 2L', 3),
      line('3.99', 3, x: 300),
      line('BREAD', 4),
      line('4.50', 4, x: 300),
      line('SUBTOTAL', 5),
      line('54.20', 5, x: 300),
      line('TOTAL', 6),
      line('\$54.20', 6, x: 300),
      line('GST INCLUDED', 7),
      line('7.07', 7, x: 300),
      line('CASH', 8),
      line('60.00', 8, x: 300),
    ], imagePath: 'r.jpg');

    expect(result.merchant.value, 'New World Victoria St');
    expect(result.amount.value, 54.20);
    expect(result.date.value, DateTime(2026, 9, 18));
    expect(result.category.value, Categories.food);
    expect(result.weakestFieldName, isNull);
  });

  test('"TOTAL INCL GST" is still the total, with amounts like 1,234.50', () {
    final result = parser.parse([
      line('Mercury Energy', 0),
      line('Account 1234567', 1),
      line('TOTAL INCL GST \$1,234.50', 2),
      line('Total includes GST of \$161.02', 3),
    ], imagePath: 'r.jpg');

    expect(result.amount.value, 1234.50);
    expect(result.category.value, Categories.other);
  });

  test('amount is on the row just below the label', () {
    final result = parser.parse([
      line('Coffee Club', 0),
      line('Flat White', 1),
      line('5.50', 1, x: 300),
      line('Amount Due', 2),
      line('\$5.50', 3),
    ], imagePath: 'r.jpg');

    expect(result.amount.value, 5.50);
    expect(result.category.value, Categories.food);
  });

  test('no total label: takes the largest amount and marks it low confidence', () {
    final result = parser.parse([
      line('Z ENERGY SYMONDS ST', 0),
      line('Unleaded 91', 1),
      line('61.00', 1, x: 300),
      line('Pump 4', 2),
    ], imagePath: 'r.jpg');

    expect(result.merchant.value, 'Z Energy Symonds St');
    expect(result.amount.value, 61.00);
    expect(result.amount.isLowConfidence, isTrue);
    expect(result.category.value, Categories.transport);
  });

  test('written-out and ISO dates; ignores future dates', () {
    DateTime dateOf(String text) => parser
        .parse([line('Shop', 0), line(text, 1)], imagePath: 'r.jpg')
        .date
        .value;

    expect(dateOf('18 Sep 2026'), DateTime(2026, 9, 18));
    expect(dateOf('Sept 3, 2026'), DateTime(2026, 9, 3));
    expect(dateOf('2026-08-01'), DateTime(2026, 8, 1));
    expect(dateOf('09/13/2026'), DateTime(2026, 9, 13), reason: 'US style');

    final future =
        parser.parse([line('Shop', 0), line('01/12/2026', 1)], imagePath: '');
    expect(future.date.isLowConfidence, isTrue,
        reason: '1/12/2026 is in the future, so it must not be read as 12/1');
  });

  test('a date like 18.08.26 is not read as an amount', () {
    final result = parser.parse([
      line('Four Square', 0),
      line('18.08.26', 1),
    ], imagePath: 'r.jpg');

    expect(result.amount.value, 0);
    expect(result.date.value, DateTime(2026, 8, 18));
  });

  test('low OCR confidence lowers the field confidence', () {
    final result = parser.parse([
      line('Countdown Metro', 0),
      line('Date 20/09/2026', 1),
      line('TOTAL', 2),
      line('32.75', 2, x: 300, conf: 0.5),
    ], imagePath: 'r.jpg');

    expect(result.amount.value, 32.75);
    expect(result.weakestFieldName, 'Amount');
  });
}
