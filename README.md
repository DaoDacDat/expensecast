# ExpenseCast

**Predictive Expense Management App** — COMP826 project by Dac Dat Dao (ID 25301423).
A Flutter app (Android and iOS) that turns a photo of a receipt into a transaction and turns the transaction history into a weekly spending forecast, **entirely on the phone**. THIS PROJECT HAS BEEN TESTED ON IOS DEVICE, NOT ON ANDROID SO YOU SHOULD RUN ON IOS TO MAKE SURE IT WILL WORK CORRECTLY.

The Milestone 2 report (development and evaluation) is in [`report/`](report/); the Milestone 1 version of the sources is kept in `report/_backup_pre_feedback/`.

---

## Why it is useful

Students on a tight budget usually find out they have overspent *after* the money is gone. Bank apps show what was spent, not what is likely to happen next, and apps that do forecast (Mint, Expensify, YNAB) either need a bank link and an account on someone else's server or need every purchase typed in by hand.

ExpenseCast removes both barriers:

* **Low effort** — scan a receipt; the app reads amount, merchant and date and shows a confidence for *each field*, so the user checks only the one it is unsure about.
* **Early warning** — a small recurrent model (GRU) forecasts the next 7 days per category and marks each budget *on track*, *watch* or *at risk*.
* **Private** — there is no server. Receipts, history and the model all stay on the device, and the scanned image is deleted after use.

## Key facts

| | |
|---|---|
| Platforms | Android; iOS 15.5 or later (physical device needed for the scanner) |
| Toolchain | Flutter 3.27 or later, Dart 3.6 or later |
| Architecture | MVVM with `provider` and `ChangeNotifier`; services behind interfaces, injected in `lib/app.dart` |
| Size | 34 Dart files, 4,343 lines in `lib/` (10 views, 6 widgets, 4 ViewModels) |
| Receipt capture | `cunning_document_scanner` (ML Kit document scanner on Android, VisionKit on iOS) → `google_mlkit_text_recognition` (on-device OCR) → rule-based `receipt_parser.dart` |
| Forecast model | Two GRU layers (32 and 16 units), 8,327 parameters, float32, 0.40 MB, run through `tflite_flutter`; input history `[1,60,7]`, future calendar `[1,7,5]`, category one-hot `[1,3]`; output 7 daily values; categories Food, Other, Transportation |
| Model contract | [`assets/models/model_info.json`](assets/models/model_info.json) (tensor shapes, scales, SHA-256 of the model file; the app checks the tensor shapes when it loads the model) |
| Model provenance | Trained offline on a public Kaggle ledger of 102 days in INR ([tharunprabu/my-expenses-data](https://www.kaggle.com/datasets/tharunprabu/my-expenses-data)) |
| Fallback | If the model is missing, the contract check fails or history is too short, the app shows a 7-day moving average and says so on screen |
| Tests | 24 test cases in `test/` (parser, ViewModels, forecast engine, model-input golden values) |
| Sign-in | Simulated: any valid e-mail and a password of 6 or more characters |
| Data | In memory only; the first launch seeds 60 days of demo data |

## How to run

You need a Flutter SDK (3.27 or later) and either an Android phone with USB debugging or an iPhone with a developer certificate. The emulator can run everything except the scanner.

```bash
git clone https://github.com/DaoDacDat/expensecast.git
cd expensecast

flutter doctor            # fix anything it reports first
flutter pub get

# iOS only
cd ios && pod install && cd ..
# then open ios/Runner.xcworkspace once in Xcode and choose your signing team

flutter devices           # find your device id
flutter run -d <device-id>
```

Optional checks:

```bash
flutter analyze
flutter test              # note: test/widget_test.dart is a stale default test and fails; the other 23 cases target current code
```

On first launch sign in with any valid e-mail and a password of 6 or more characters. Open **Scan** to capture a receipt, **Review** to confirm it, and **Insights** to run a forecast.

## Reproduce the forecast evaluation

The back-test used in the Milestone 2 report loads the app's own model file and runs it on synthetic ledgers (about three seconds, fixed seeds).

```bash
pip install ai-edge-litert numpy
python3 report/evaluation/eval_forecast.py \
    assets/models/expensecast_gru_float32.tflite \
    report/evaluation/eval_results.json \
    assets/models/model_info.json
```

## Repository layout

```text
lib/
  main.dart, app.dart        entry point and dependency injection
  core/                      theme, categories, formatters
  models/                    Transaction, Budget, OcrResult, ForecastResult, ForecastMethod
  services/                  ocr_service, receipt_parser, forecast_service, gru_forecaster
  viewmodels/                auth, transaction, budget, forecast
  views/                     login, shell, home, capture, review, manual entry, budgets,
                             insights, history, more
  widgets/                   risk card, forecast chart, tiles, pickers, privacy note
assets/models/               GRU model (.tflite) and its contract (model_info.json)
test/                        unit and golden tests
report/                      LaTeX reports, diagrams, figures, evaluation script and results
```

## Code-to-report map (Milestone 2)

| Report element | Source |
|---|---|
| Dependency injection | `lib/app.dart` |
| Scan and Review pages (F3, F4) | `lib/views/capture_view.dart`, `lib/views/review_view.dart` |
| OCR service and stub | `lib/services/ocr_service.dart` |
| Parser and per-field confidence | `lib/services/receipt_parser.dart`, `lib/models/ocr_result.dart` |
| Forecast engine, fallback, scaling | `lib/services/forecast_service.dart` |
| Model contract and input builder | `lib/services/gru_forecaster.dart`, `assets/models/model_info.json` |
| ViewModels | `lib/viewmodels/*.dart` |
| Insights, risk cards, chart (F7) | `lib/views/insights_view.dart`, `lib/widgets/risk_card.dart`, `lib/widgets/forecast_chart.dart` |
| Tests | `test/*.dart` |
| Back-test script and results | `report/evaluation/` |

## Known limitations

These are discussed in the Milestone 2 report (Conclusion and Recommendations).

* Transactions and budgets are not stored: they are lost when the app restarts. There is no server, real sign-in or notifications.
* On the real 102-day ledger and on synthetic ledgers the GRU is **less accurate than a plain moving average**; the app therefore labels the method it used. Treat *watch* and *at risk* as estimates.
* Spending on Home and Budgets is calculated over the calendar month and ignores the chosen budget period.
* Every scanned receipt is currently saved with the *corrected* flag.
* The recogniser reads Latin script only, and the parser is tuned to New Zealand receipts.
* OCR accuracy, phone performance and usability with real users were not measured.

## Building the reports

```bash
cd report
latexmk -pdf main.tex      # needs a TeX Live installation with tikz, natbib, xltabular, listings
```
