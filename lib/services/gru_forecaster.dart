import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../core/categories.dart';

/// Contract of `expensecast_gru_float32.tflite` (see the training notebook and
/// the model README). Inputs are used by runtime position, in this order:
/// 0 `history` [1,60,7], 1 `future_calendar` [1,7,5], 2 `category` [1,3];
/// output 0 `Identity` [1,7] = daily spend for the next 7 days (not cumulative).
class GruSpec {
  static const asset = 'assets/models/expensecast_gru_float32.tflite';

  /// Optional export metadata; read when present, defaults below otherwise.
  static const infoAsset = 'assets/models/model_info.json';

  static const historyDays = 60;
  static const historyFeatures = 7;
  static const horizonDays = 7;
  static const calendarFeatures = 5;

  /// One-hot order of the `category` input: the model was trained on the
  /// alphabetically sorted category names.
  static const categories = [
    Categories.food,
    Categories.other,
    Categories.transport,
  ];
  static int get categorySize => categories.length;

  /// Divisor for log1p(daily transaction count); the training ledger's maximum
  /// was 5 transactions in a day: log1p(5).
  static final defaultCountScale = math.log(6);
}

/// Runs the GRU model. Kept behind an interface so [ForecastEngine] can be
/// tested without the native TensorFlow Lite library.
abstract class GruRunner {
  /// Divisor applied to `log1p(count)` in the `history` tensor.
  double get countScale;

  /// [history] is [60][7], [futureCalendar] is [7][5], [category] is [3].
  /// Returns the 7 daily predictions, in the same (scaled) units as the
  /// amount feature of [history].
  Future<List<double>> run({
    required List<List<double>> history,
    required List<List<double>> futureCalendar,
    required List<double> category,
  });
}

/// Calendar features for one day, in training order:
/// dow sin/cos (Monday = 0), day-in-month (0..1), day-of-year sin/cos.
List<double> calendarFeatures(DateTime day) {
  final dow = 2 * math.pi * (day.weekday - 1) / 7;
  final daysInMonth = DateTime(day.year, day.month + 1, 0).day;
  final dom = (day.day - 1) / math.max(daysInMonth - 1, 1);
  final isLeap =
      (day.year % 4 == 0 && day.year % 100 != 0) || day.year % 400 == 0;
  final dayOfYear = DateTime.utc(day.year, day.month, day.day)
          .difference(DateTime.utc(day.year, 1, 1))
          .inDays +
      1;
  final phase = 2 * math.pi * (dayOfYear - 1) / (isLeap ? 366 : 365);
  return [
    math.sin(dow),
    math.cos(dow),
    dom,
    math.sin(phase),
    math.cos(phase),
  ];
}

/// The three model input tensors for one category (batch dimension omitted).
class GruInputs {
  const GruInputs(this.history, this.futureCalendar, this.category);

  final List<List<double>> history; // [60][7]
  final List<List<double>> futureCalendar; // [7][5]
  final List<double> category; // [3]
}

DateTime _shiftDays(DateTime d, int days) =>
    DateTime(d.year, d.month, d.day + days);

/// Builds the model inputs. [daily] and [counts] hold the last 60 days of spend
/// and transaction counts for [category], oldest first, ending on [lastDay].
/// The 7 forecast days start the day after [lastDay].
///
/// history row = [amount / moneyScale, log1p(count) / countScale, ...5 calendar].
GruInputs buildGruInputs({
  required String category,
  required List<double> daily,
  required List<double> counts,
  required DateTime lastDay,
  required double moneyScale,
  required double countScale,
}) {
  assert(daily.length == GruSpec.historyDays && counts.length == daily.length);
  final first = _shiftDays(lastDay, -(GruSpec.historyDays - 1));
  final history = List.generate(GruSpec.historyDays, (i) {
    return [
      daily[i] / moneyScale,
      math.log(1 + counts[i]) / countScale,
      ...calendarFeatures(_shiftDays(first, i)),
    ];
  });
  final future = List.generate(
    GruSpec.horizonDays,
    (i) => calendarFeatures(_shiftDays(lastDay, i + 1)),
  );
  final oneHot = List<double>.generate(
    GruSpec.categorySize,
    (i) => GruSpec.categories.indexOf(category) == i ? 1.0 : 0.0,
  );
  return GruInputs(history, future, oneHot);
}

class TfliteGruRunner implements GruRunner {
  Interpreter? _interpreter;
  double _countScale = GruSpec.defaultCountScale;

  @override
  double get countScale => _countScale;

  Future<Interpreter> _load() async {
    final existing = _interpreter;
    if (existing != null) return existing;

    final interpreter = await Interpreter.fromAsset(GruSpec.asset);
    try {
      _checkShapes(interpreter);
      await _readInfo();
    } catch (_) {
      interpreter.close();
      rethrow;
    }
    return _interpreter = interpreter;
  }

  /// Fails early if the shipped model does not match the contract above.
  void _checkShapes(Interpreter interpreter) {
    final expected = [
      [1, GruSpec.historyDays, GruSpec.historyFeatures],
      [1, GruSpec.horizonDays, GruSpec.calendarFeatures],
      [1, GruSpec.categorySize],
    ];
    final inputs = interpreter.getInputTensors();
    if (inputs.length != expected.length) {
      throw StateError('model has ${inputs.length} inputs, expected 3');
    }
    for (var i = 0; i < expected.length; i++) {
      if (inputs[i].shape.join(',') != expected[i].join(',')) {
        throw StateError(
          'input $i shape ${inputs[i].shape}, expected ${expected[i]}',
        );
      }
    }
    final out = interpreter.getOutputTensor(0).shape;
    if (out.join(',') != '1,${GruSpec.horizonDays}') {
      throw StateError(
          'output shape $out, expected [1, ${GruSpec.horizonDays}]');
    }
  }

  /// Reads `preprocessor` from model_info.json if it was shipped, and checks it
  /// agrees with [GruSpec.categories].
  Future<void> _readInfo() async {
    final String text;
    try {
      text = await rootBundle.loadString(GruSpec.infoAsset);
    } catch (_) {
      return; // optional file
    }
    final info = jsonDecode(text) as Map<String, dynamic>;
    final prep = (info['preprocessor'] ?? info) as Map<String, dynamic>;

    final cats = prep['categories'];
    if (cats is List && cats.join(',') != GruSpec.categories.join(',')) {
      throw StateError(
        'model categories $cats differ from app categories ${GruSpec.categories}',
      );
    }
    final scale = prep['count_scale'];
    if (scale is num) _countScale = scale.toDouble();
  }

  @override
  Future<List<double>> run({
    required List<List<double>> history,
    required List<List<double>> futureCalendar,
    required List<double> category,
  }) async {
    final interpreter = await _load();

    final inputs = <Object>[
      [history],
      [futureCalendar],
      [category],
    ];
    final output = [List<double>.filled(GruSpec.horizonDays, 0)];
    interpreter.runForMultipleInputs(inputs, {0: output});
    return output.first;
  }

  void close() {
    _interpreter?.close();
    _interpreter = null;
  }
}
