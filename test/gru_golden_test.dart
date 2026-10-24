import 'package:expensecast/core/categories.dart';
import 'package:expensecast/services/gru_forecaster.dart';
import 'package:flutter_test/flutter_test.dart';

/// Checks [buildGruInputs] against the model export's golden_test.json
/// (Food, history 2021-12-26 .. 2022-02-23, forecast from 2022-02-24).
/// Only the feature builder is covered here; running the .tflite itself needs
/// a device.
void main() {
  const moneyScale = 325.4186096191406; // model_info.json: Food
  const countScale = 1.7917594909667969;

  const amounts = <double>[
    0, 165, 14, 0, 65, 0, 85, 200, 310, 213, 953, 907.8099975585938, 15, //
    535.2999877929688, 0, 106, 135.5, 301.75, 66, 1530, 70, 0, 100,
    508.1499938964844, 171, 0, 225, 0, 1283, 173, 277, 140, 279, 148, 0, 380,
    0, 0, 120, 50, 80, 0, 275, 0, 0, 0, 641, 373, 571, 0, 0, 0, 640, 80, 348,
    741, 200, 0, 0, 83,
  ];
  const counts = <double>[
    0,
    2,
    1,
    0,
    3,
    0,
    1,
    1,
    2,
    2,
    3,
    3,
    1,
    1,
    0,
    1,
    1,
    1,
    1,
    1,
    1,
    0,
    1,
    3,
    1,
    0,
    2,
    0,
    5,
    2,
    2,
    2,
    1,
    2,
    0,
    3,
    0,
    0,
    1,
    1,
    1,
    0,
    2,
    0,
    0,
    0,
    1,
    1,
    2,
    0,
    0,
    0,
    2,
    1,
    1,
    3,
    1,
    0,
    0,
    1,
  ];

  final inputs = buildGruInputs(
    category: Categories.food,
    daily: amounts,
    counts: counts,
    lastDay: DateTime(2022, 2, 23),
    moneyScale: moneyScale,
    countScale: countScale,
  );

  void expectRow(List<double> actual, List<double> expected) {
    expect(actual.length, expected.length);
    for (var i = 0; i < expected.length; i++) {
      expect(actual[i], closeTo(expected[i], 1e-5), reason: 'feature $i');
    }
  }

  test('history rows match the golden normalized input', () {
    expect(inputs.history.length, 60);
    // 2021-12-26 (start), 12-27, 2022-01-01 (day-in-month 0, year phase 0),
    // 2022-01-23 (5 transactions), 2022-02-23 (last day).
    expectRow(inputs.history[0], [
      0.0, 0.0, -0.7818315029144287, 0.6234897971153259, 0.8333333134651184,
      -0.1031017005443573, 0.9946708083152771, //
    ]);
    expectRow(inputs.history[1], [
      0.5070392489433289, 0.6131471991539001, 0.0, 1.0, 0.8666666746139526,
      -0.08596479892730713, 0.9962981939315796, //
    ]);
    expectRow(inputs.history[6], [
      0.26120203733444214, 0.38685280084609985, -0.9749279022216797,
      -0.22252093255519867, 0.0, 0.0, 1.0, //
    ]);
    expectRow(inputs.history[28], [
      3.9426140785217285, 1.0, -0.7818315029144287, 0.6234897971153259,
      0.7333333492279053, 0.3697245419025421, 0.9291414022445679, //
    ]);
    expectRow(inputs.history[59], [
      0.25505608320236206, 0.38685280084609985, 0.9749279022216797,
      -0.22252093255519867, 0.8148148059844971, 0.7909456491470337,
      0.6118863821029663, //
    ]);
  });

  test('future calendar (2022-02-24 .. 2022-03-02) matches the golden input',
      () {
    const expected = <List<double>>[
      [
        0.4338837265968323,
        -0.9009688496589661,
        0.8518518805503845,
        0.801361083984375,
        0.598180890083313
      ],
      [
        -0.4338837265968323,
        -0.9009688496589661,
        0.8888888955116272,
        0.8115390539169312,
        0.5842981934547424
      ],
      [
        -0.9749279022216797,
        -0.22252093255519867,
        0.9259259104728699,
        0.8214765787124634,
        0.5702422857284546
      ],
      [
        -0.7818315029144287,
        0.6234897971153259,
        0.9629629850387573,
        0.8311706185340881,
        0.5560174584388733
      ],
      [0.0, 1.0, 1.0, 0.8406184315681458, 0.541627824306488],
      [
        0.7818315029144287,
        0.6234897971153259,
        0.0,
        0.8498170971870422,
        0.5270777344703674
      ],
      [
        0.9749279022216797,
        -0.22252093255519867,
        0.03333333507180214,
        0.8587639331817627,
        0.5123714208602905
      ],
    ];
    expect(inputs.futureCalendar.length, 7);
    for (var i = 0; i < 7; i++) {
      expectRow(inputs.futureCalendar[i], expected[i]);
    }
  });

  test('category one-hot is Food = [1, 0, 0]', () {
    expect(inputs.category, [1.0, 0.0, 0.0]);
  });

  test('app categories match model_info.json order', () {
    expect(GruSpec.categories, ['Food', 'Other', 'Transportation']);
  });
}
