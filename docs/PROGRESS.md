# Theo dõi Tiến độ & Bàn giao Dự án (PROGRESS)

> **Dành cho nhân sự hoặc AI model mới tiếp nhận:** Đọc file này đầu tiên để biết dự án đang ở đâu, các tính năng nào đã chạy ổn định và bước tiếp theo cần làm ngay.

- **Cập nhật lần cuối:** 2026-11-16
- **Giai đoạn hiện tại (Current Phase):** Hoàn thành **Phase 3 (Thiết bị Bluetooth & Ghim Menu Bar)** — Sẵn sàng chuyển sang **Phase 4**
- **Nhánh chính:** `main`
- **Trạng thái Build / Test:** `TEST SUCCEEDED` (14/14 test cases: `BatteryInfoTests` 5/5, `AlertEngineTests` 6/6, `BluetoothBatteryTests` 3/3, `SWIFT_STRICT_CONCURRENCY = complete`)

---

## 1. Tổng quan Lộ trình & Trạng thái

| Phase | Tên giai đoạn | Trạng thái | Ghi chú |
| :--- | :--- | :--- | :--- |
| **Phase 0** | Khởi tạo Repo, GitHub & Tài liệu chuẩn | ✅ Hoàn thành | Git, GitHub (`khuglog/powerman`), CI, Docs bàn giao |
| **Phase 1** | Core Battery (`IOKit`) + Menu Bar & Popover | ✅ Hoàn thành | Đọc pin thật Apple Silicon, Menu Bar 3 style + 4 color modes |
| **Phase 2** | Hệ thống Cảnh báo đa mức (`Alerts` + Glow + Popup) | ✅ Hoàn thành | Low/Charged/Power rules, Overlay đa màn hình, 8 âm tổng hợp + 14 âm macOS |
| **Phase 3** | Thiết bị Bluetooth (`Devices`) & Ghim Menu Bar | ✅ Hoàn thành | `SPBluetoothDataType` + `IORegistry` + `IOPS` + `CoreBluetooth`, Pin Menu Bar |
| **Phase 4** | Sức khỏe pin & Biểu đồ lịch sử (`Battery` + SwiftData) | ⏳ Chưa bắt đầu | Lưu lịch sử nền, Charts `6h`–`14d`, Daily Usage, Top Energy Apps |
| **Phase 5** | Giới hạn sạc 80–100% (`Charge Limit`) | ⏳ Chưa bắt đầu | Kiểm chứng Native Charge Limit trên macOS 27 vs SMC Helper |
| **Phase 6** | General Settings, Tiện ích hệ thống & Đóng gói | ⏳ Chưa bắt đầu | Đa ngôn ngữ, Launch at Login, Dismiss macOS notif, DMG/Notarize |

---

## 2. Checklist Chi tiết

### Phase 0: GitHub & Tài liệu Bàn giao
- [x] Khởi tạo `.gitignore`, `README.md`, `CONTRIBUTING.md`, `CHANGELOG.md`, `AGENTS.md`
- [x] Viết `docs/ARCHITECTURE.md` và `docs/PROGRESS.md`
- [x] Thiết lập GitHub Actions CI (`.github/workflows/ci.yml`)
- [x] Khởi tạo Git local, tạo repo GitHub (`khuglog/powerman`) và push lần đầu

### Phase 1: Core Battery & Menu Bar
- [x] Tạo `Powerman.xcodeproj` (Non-sandboxed, `LSUIElement = YES`, Swift Strict Concurrency `complete`)
- [x] Xây dựng `BatteryInfo` & `BatterySnapshotParser` (hỗ trợ `AppleSmartBattery`, `BatteryData`, `AppleSmartBatteryPack`)
- [x] Xây dựng `IOKitBatteryService` (event-driven qua `IOPSNotificationCreateRunLoopSource` + timer 30s)
- [x] Xây dựng `AppState`, `AppDelegate`, `MenuBarController` & `MenuBarIconView` (3 styles, 4 color modes: Auto/Monochrome/White/Black)
- [x] Hoàn thiện `MenuBarPopoverView` & tab `Menu Bar` / `Battery` trong Settings
- [x] Viết & pass `BatteryInfoTests` (5/5 tests)

### Phase 2: Hệ thống Cảnh báo (`Alerts`)
- [x] Tạo model `AlertRule`, `PowerSourceAlertConfig`, `ActiveAlertPresentation` + lưu trữ `AppSettings`
- [x] Xây dựng `AlertEngine` có cơ chế hysteresis 3% & tự động đóng persistent alert khi đổi nguồn
- [x] Xây dựng `OverlayWindowManager` hỗ trợ đa màn hình (`ScreenBorderGlowView` & `FloatingAlertBubbleView`)
- [x] Xây dựng `SystemSoundPlayer` & `SynthesizedSoundGenerator` (8 âm thanh tổng hợp + 14 âm macOS)
- [x] Hoàn thiện `AlertsSettingsView` (CRUD rule, `ColorPicker`, Preview & `▶ Test`, nút nghe thử `🔊`)
- [x] Viết & pass `AlertEngineTests` (6/6 tests)

### Phase 3: Thiết bị Bluetooth (`Devices`)
- [x] Tạo model `BluetoothDeviceBattery` & `DeviceUserPreference` (`Powerman/Models/BluetoothDeviceBattery.swift`)
- [x] Xây dựng `BluetoothBatteryParser` & `BluetoothBatteryService` kết hợp `SPBluetoothDataType`, `IORegistry HID`, `IOPS Accessories`, `IOBluetooth` & `CoreBluetooth` (`0x180F`)
- [x] Cập nhật `MenuBarController` & `MenuBarIconView` hiển thị các thiết bị đã ghim ngay trên Menu Bar
- [x] Cập nhật `MenuBarPopoverView` (`Connected Devices` xếp pin thấp lên đầu, hiển thị L/R/Case AirPods & thanh tiến trình)
- [x] Hoàn thiện `DevicesSettingsView` (cảnh báo pin riêng từng thiết bị, ghim Menu Bar, ẩn khỏi dropdown) & `Device Batteries` trong `MenuBarSettingsView` (thêm & sắp xếp thứ tự)
- [x] Viết & pass `BluetoothBatteryTests` (3/3 tests)

### Phase 4: Sức khỏe pin & Biểu đồ lịch sử (`Battery`) — *Kế tiếp*
- [ ] Tạo model lưu trữ lịch sử (`BatteryHistorySample` dùng SwiftData hoặc SQLite nhẹ)
- [ ] Xây dựng `BatteryHistoryStore` ghi snapshot nền mỗi 5 phút & khi đổi trạng thái nguồn
- [ ] Xây dựng `EnergyConsumerService` đọc các app tiêu thụ nhiều năng lượng cho Popover (`Apps Using Significant Energy`)
- [ ] Hoàn thiện `BatteryOverviewView` với Swift Charts (`6h`, `12h`, `24h`, `7d`, `14d`), `Daily Usage`, `Battery Health` & `Battery Cycles`

---

## 3. Danh sách File Trọng tâm Hiện tại

- **Models:** `BatteryInfo.swift`, `AppSettings.swift`, `AlertRule.swift`, `BluetoothDeviceBattery.swift`
- **Services:** `IOKitBatteryService.swift`, `AlertEngine.swift`, `OverlayWindowManager.swift`, `SoundPlayer.swift`, `BluetoothBatteryService.swift`
- **App:** `PowermanApp.swift`, `AppDelegate.swift`, `AppState.swift`
- **UI:** `MenuBarController.swift`, `MenuBarIconView.swift`, `MenuBarPopoverView.swift`, `FloatingAlertBubbleView.swift`, `ScreenBorderGlowView.swift`, `SettingsRootView.swift`, `MenuBarSettingsView.swift`, `BatteryOverviewView.swift`, `AlertsSettingsView.swift`, `DevicesSettingsView.swift`
- **Tests:** `BatteryInfoTests.swift`, `AlertEngineTests.swift`, `BluetoothBatteryTests.swift`

---

## 4. Bước tiếp theo cần làm ngay (Next Immediate Steps)

1. Bắt đầu **Phase 4**: thiết kế `BatteryHistorySample` & `BatteryHistoryStore` (SwiftData) để ghi nhận lịch sử mức pin, nhiệt độ, chu kỳ và thời gian sử dụng theo ngày.
2. Vẽ biểu đồ lịch sử bằng **Swift Charts** trong `BatteryOverviewView` với bộ lọc `6h`, `12h`, `24h`, `7d`, `14d`.
3. Triển khai `EnergyConsumerService` cho mục `Apps Using Significant Energy` trong `MenuBarPopoverView`.

---

## 5. Ghi chú Kỹ thuật & Known Issues

- **Bluetooth permissions:** Khi chạy lần đầu có `CBCentralManager`, macOS có thể hỏi quyền Bluetooth (`NSBluetoothAlwaysUsageDescription`).
- **Xcode Build trên môi trường bị sandbox:** Cần chạy `xcodebuild` ngoài sandbox nếu `swift-plugin-server` bị chặn.
