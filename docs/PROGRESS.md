# Theo dõi Tiến độ & Bàn giao Dự án (PROGRESS)

> **Dành cho nhân sự hoặc AI model mới tiếp nhận:** Đọc file này đầu tiên để biết dự án đang ở đâu, các tính năng nào đã chạy ổn định và bước tiếp theo cần làm ngay.

- **Cập nhật lần cuối:** 2026-11-16
- **Giai đoạn hiện tại (Current Phase):** Hoàn thành **Phase 4 (Sức khỏe pin, Biểu đồ lịch sử & Apps dùng nhiều năng lượng)** — Sẵn sàng chuyển sang **Phase 5**
- **Nhánh chính:** `main`
- **Trạng thái Build / Test:** `TEST SUCCEEDED` (18/18 test cases: `BatteryInfoTests` 5/5, `AlertEngineTests` 6/6, `BluetoothBatteryTests` 3/3, `BatteryHistoryTests` 4/4, `SWIFT_STRICT_CONCURRENCY = complete`)

---

## 1. Tổng quan Lộ trình & Trạng thái

| Phase | Tên giai đoạn | Trạng thái | Ghi chú |
| :--- | :--- | :--- | :--- |
| **Phase 0** | Khởi tạo Repo, GitHub & Tài liệu chuẩn | ✅ Hoàn thành | Git, GitHub (`khuglog/powerman`), CI, Docs bàn giao |
| **Phase 1** | Core Battery (`IOKit`) + Menu Bar & Popover | ✅ Hoàn thành | Đọc pin thật Apple Silicon, Menu Bar 3 style + 4 color modes |
| **Phase 2** | Hệ thống Cảnh báo đa mức (`Alerts` + Glow + Popup) | ✅ Hoàn thành | Low/Charged/Power rules, Overlay đa màn hình, 8 âm tổng hợp + 14 âm macOS |
| **Phase 3** | Thiết bị Bluetooth (`Devices`) & Ghim Menu Bar | ✅ Hoàn thành | `SPBluetoothDataType` + `IORegistry` + `IOPS` + `CoreBluetooth`, Pin Menu Bar |
| **Phase 4** | Sức khỏe pin & Biểu đồ lịch sử (`Battery` + Charts) | ✅ Hoàn thành | Lưu lịch sử 14 ngày, Swift Charts `6h`–`14d`, Daily Usage, Top Energy Apps |
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
- [x] Tạo model `BluetoothDeviceBattery` & `DeviceUserPreference`
- [x] Xây dựng `BluetoothBatteryParser` & `BluetoothBatteryService` (`SPBluetoothDataType`, `IORegistry HID`, `IOPS`, `IOBluetooth`, `CoreBluetooth`)
- [x] Cập nhật `MenuBarController` & `MenuBarIconView` hiển thị thiết bị đã ghim lên Menu Bar
- [x] Cập nhật `MenuBarPopoverView` (`Connected Devices`) & hoàn thiện `DevicesSettingsView`
- [x] Viết & pass `BluetoothBatteryTests` (3/3 tests)

### Phase 4: Sức khỏe pin & Biểu đồ lịch sử (`Battery`)
- [x] Tạo model `BatteryHistorySample`, `DailyBatteryUsage`, `HistoryTimeframe` & `BatteryHistoryAnalytics` (`Powerman/Models/BatteryHistory.swift`)
- [x] Xây dựng `JSONBatteryHistoryStore` lưu trữ lịch sử 14 ngày tại `Application Support/Powerman/battery_history.json`
- [x] Xây dựng `ProcessEnergyConsumerService` dùng `Darwin.proc_pidinfo` (`PROC_PIDTASKINFO` + `PROC_PIDTBSDINFO`) gộp tiến trình con về app mẹ không cần root
- [x] Hoàn thiện biểu đồ **Swift Charts** trong `BatteryOverviewView` (`6h`, `12h`, `24h`, `7d`, `14d`, Daily Usage, Temperature trend) & danh sách app dùng nhiều năng lượng trong `MenuBarPopoverView`
- [x] Viết & pass `BatteryHistoryTests` (4/4 tests)

### Phase 5: Giới hạn sạc 80–100% (`Charge Limit`) — *Kế tiếp*
- [ ] Khảo sát thực nghiệm API / CLI `Charge Limit` gốc trên `macOS 27.0.1` (`Mac15,6`) vs Privileged Helper SMC (`SMAppService.daemon`)
- [ ] Xây dựng `ChargeLimitService` (protocol + implementation)
- [ ] Hoàn thiện `ChargingSettingsView` (công tắc `Charge Limit`, thanh trượt 80–100% bước 5%, trạng thái thực thi & giải thích cơ chế)

---

## 3. Danh sách File Trọng tâm Hiện tại

- **Models:** `BatteryInfo.swift`, `AppSettings.swift`, `AlertRule.swift`, `BluetoothDeviceBattery.swift`, `BatteryHistory.swift`
- **Services:** `IOKitBatteryService.swift`, `BatteryHistoryStore.swift`, `EnergyConsumerService.swift`, `AlertEngine.swift`, `OverlayWindowManager.swift`, `SoundPlayer.swift`, `BluetoothBatteryService.swift`
- **App:** `PowermanApp.swift`, `AppDelegate.swift`, `AppState.swift`
- **UI:** `MenuBarController.swift`, `MenuBarIconView.swift`, `MenuBarPopoverView.swift`, `FloatingAlertBubbleView.swift`, `ScreenBorderGlowView.swift`, `SettingsRootView.swift`, `MenuBarSettingsView.swift`, `BatteryOverviewView.swift`, `AlertsSettingsView.swift`, `DevicesSettingsView.swift`
- **Tests:** `BatteryInfoTests.swift`, `AlertEngineTests.swift`, `BluetoothBatteryTests.swift`, `BatteryHistoryTests.swift`

---

## 4. Bước tiếp theo cần làm ngay (Next Immediate Steps)

1. Bắt đầu **Phase 5**: kiểm chứng cơ chế Native Charge Limit trên macOS 27 (`Mac15,6`) xem có thể đọc/ghi ngưỡng 80–100% qua framework/CLI hệ thống hay cần Privileged Helper (`SMAppService.daemon` + SMC).
2. Xây dựng `ChargeLimitService` và `UI/Settings/ChargingSettingsView.swift` (thay thế placeholder tab `Charging`).

---

## 5. Ghi chú Kỹ thuật & Known Issues

- **Lưu trữ lịch sử pin:** Dùng JSON atomic (`Application Support/Powerman/battery_history.json`) với chu kỳ thu thập tối thiểu 120s (hoặc ngay lập tức khi đổi trạng thái sạc/nguồn) và tự động xóa mẫu cũ hơn 14 ngày.
- **Xcode Build trên môi trường bị sandbox:** Cần chạy `xcodebuild` ngoài sandbox nếu `swift-plugin-server` bị chặn.
