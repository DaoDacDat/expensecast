# ExpenseCast — Milestone 1 (UI + Receipt Capture)

Bản dựng Flutter cho *Predictive Expense Management App* (COMP826, Dac Dat Dao — 25301423).
Phạm vi bản này đúng như yêu cầu: **toàn bộ giao diện 6 màn hình + chức năng chụp ảnh hoá đơn hoạt động thật**.
OCR và dự báo hiện là bản giả lập/heuristic, đặt sau interface để Sprint 2–3 thay thế mà không phải sửa UI.

---

## 1. Chạy thử

```bash
# 1. Giải nén rồi vào thư mục
cd expensecast

# 2. Sinh phần native (android/, ios/) cho máy của bạn.
#    Lệnh này KHÔNG ghi đè các file đã có sẵn trong gói.
flutter create . --project-name expensecast --platforms android,ios

# 3. Cài package
flutter pub get

# 4. Chạy trên thiết bị thật (camera không hoạt động trên emulator/simulator)
flutter run
```

> **Lưu ý:** tài khoản đăng nhập là giả lập — nhập bất kỳ email hợp lệ và mật khẩu ≥ 6 ký tự là vào được.

### Cấu hình quyền

* **Android** — `android/app/src/main/AndroidManifest.xml` đã có sẵn `CAMERA` và `READ_MEDIA_IMAGES`.
  Mở `android/app/build.gradle` và đặt `minSdkVersion 21` (gói `camera` yêu cầu).
* **iOS** — mở `ios/Runner/Info.plist` và dán các khoá trong `ios/Runner/Info.plist.additions.xml`
  vào trong `<dict>` gốc. Trong `ios/Podfile` đặt `platform :ios, '12.0'`.

---

## 2. Bản đồ code ↔ báo cáo

| Thành phần trong báo cáo | File |
|---|---|
| MVVM — View | `lib/views/*.dart` |
| MVVM — ViewModel (`ChangeNotifier`) | `lib/viewmodels/*.dart` |
| Entity `Transaction`, `Budget`, `ForecastResult`, enum `TxSource`/`BudgetPeriod` | `lib/models/` |
| `IReceiptCapture` / `MlKitOcrService` | `lib/services/ocr_service.dart` |
| `IForecastService` / `ForecastEngine` | `lib/services/forecast_service.dart` |
| Navigation model (Figure 9) | `lib/views/shell_view.dart` + `Navigator` trong từng View |
| Mockup 1 — Login / Register | `lib/views/login_view.dart` |
| Mockup 2 — Home | `lib/views/home_view.dart` |
| Mockup 3 — Receipt Capture | `lib/views/capture_view.dart` |
| Mockup 4 — OCR Review & Confirm | `lib/views/review_view.dart` |
| Mockup 5 — Budgets | `lib/views/budget_view.dart` |
| Mockup 6 — Insights & Forecast | `lib/views/insights_view.dart` |
| Manual Transaction | `lib/views/manual_transaction_view.dart` |
| History & Export, Settings & Privacy | `lib/views/history_view.dart`, `lib/views/more_view.dart` |

Ba quyết định thiết kế nêu ở mục 5.4 được cài đặt đúng như mô tả:

1. Màn hình chụp ghi rõ trên giao diện *"On-device OCR · image never uploaded"*.
2. Màn hình Review hiển thị độ tin cậy **từng trường** và nêu đích danh trường yếu nhất
   (`OcrResult.weakestFieldName`), thay vì một điểm confidence tổng.
3. Màn hình Insights thu gọn mỗi danh mục thành một trạng thái (`on track` / `watch` / `at risk`)
   thay vì đổ ra toàn bộ số liệu.

---

## 3. Luồng chụp hoá đơn (đã chạy được)

`Home → FAB "Scan receipt" → CaptureView → chụp → OCR → ReviewView → Save → Home`

`CaptureView` đã xử lý đầy đủ:

* liệt kê camera, chọn camera sau, khởi tạo `CameraController` (không bật audio);
* khung canh hoá đơn bốn góc chữ L + làm tối vùng ngoài;
* bật/tắt đèn flash (`FlashMode.torch`), chọn ảnh từ thư viện;
* giải phóng camera khi app xuống nền và khởi tạo lại khi quay lại (`didChangeAppLifecycleState`);
* thông báo rõ ràng khi người dùng từ chối quyền, khi máy không có camera, hoặc khi chụp lỗi —
  kèm lối thoát "Choose a photo instead".

Ảnh chụp nằm trong thư mục tạm của app; chưa có bước xoá sau khi trích xuất — sẽ làm ở Sprint 2
cùng lúc với OCR thật.

---

## 4. Việc còn lại theo kế hoạch trong báo cáo

| Sprint | Việc | Chỗ cần sửa |
|---|---|---|
| 2 | OCR thật bằng `google_mlkit_text_recognition` | tạo `MlKitOcrService implements OcrService`, đổi một dòng trong `lib/app.dart` |
| 2 | Lưu bền vững bằng `sqflite` | thêm `TransactionRepository`/`BudgetRepository`, ViewModel gọi repository thay vì list trong bộ nhớ |
| 3 | Dự báo TensorFlow Lite | tạo `ForecastEngine implements ForecastService` (chạy trong isolate qua `compute`) |
| 3 | Thông báo at-risk | `flutter_local_notifications`, gọi từ `ForecastViewModel` khi `isAtRisk` |
| 3 | Xuất CSV ra file | `HistoryView._exportCsv` hiện copy vào clipboard; đổi sang `path_provider` + `share_plus` |

Vì mọi ViewModel chỉ phụ thuộc vào interface, các bước trên không đụng tới code giao diện.

---

## 5. Test

```bash
flutter test
```

`test/view_model_test.dart` kiểm tra logic bản nháp OCR, quy tắc `correctedOcr`, kiểm tra hợp lệ
trước khi lưu, và việc lọc danh mục vượt hạn mức — dùng service stub, đúng như lập luận về
testability ở mục 7.3 của báo cáo.
