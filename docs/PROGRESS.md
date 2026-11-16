# Theo dõi Tiến độ & Bàn giao Dự án (PROGRESS)

> **Dành cho nhân sự hoặc AI model mới tiếp nhận:** Đọc file này đầu tiên để biết dự án đang ở đâu, các tính năng nào đã chạy ổn định và bước tiếp theo cần làm ngay.

- **Cập nhật lần cuối:** 2026-11-16
- **Giai đoạn hiện tại (Current Phase):** Hoàn thành **Phase 2 (Hệ thống Cảnh báo đa mức, Popup nổi, Viền sáng màn hình & Âm thanh)** — Sẵn sàng chuyển sang **Phase 3**
- **Nhánh chính:** `main`
- **Trạng thái Build / Test:** `TEST SUCCEEDED` (11/11 test cases: `BatteryInfoTests` 5/5, `AlertEngineTests` 6/6, `SWIFT_STRICT_CONCURRENCY = complete`)

---

## 1. Tổng quan Lộ trình & Trạng thái

| Phase | Tên giai đoạn | Trạng thái | Ghi chú |
| :--- | :--- | :--- | :--- |
| **Phase 0** | Khởi tạo Repo, GitHub & Tài liệu chuẩn | ✅ Hoàn thành | Git, GitHub (`khuglog/powerman`), CI, Docs bàn giao |
| **Phase 1** | Core Battery (`IOKit`) + Menu Bar & Popover | ✅ Hoàn thành | Đọc pin thật Apple Silicon, Menu Bar 3 style + 4 color modes |
| **Phase 2** | Hệ thống Cảnh báo đa mức (`Alerts` + Glow + Popup) | ✅ Hoàn thành | Low/Charged/Power rules, Overlay đa màn hình, Sound, Live Test |
| **Phase 3** | Thiết bị Bluetooth (`Devices`) & Ghim Menu Bar | ⏳ Chưa bắt đầu | IOBluetooth/IORegistry/BLE, Pin lên Menu Bar, Ẩn/Cảnh báo riêng |
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
- [x] Tạo model `AlertRule`, `PowerSourceAlertConfig`, `ActiveAlertPresentation` trong `Powerman/Models/AlertRule.swift` + lưu trữ `AppSettings`
- [x] Xây dựng `AlertEngine` có cơ chế hysteresis 3% & tự động đóng persistent alert khi cắm/rút sạc ngược lại
- [x] Xây dựng `OverlayWindowManager` hỗ trợ đa màn hình (`NSPanel` không cướp focus):
  - [x] `ScreenBorderGlowView` (viền sáng toàn màn hình theo màu, hiệu ứng pulse khi `Persistent = true`, click-through)
  - [x] `FloatingAlertBubbleView` (vị trí `Top of Screen` / `Center of Screen`, nút đóng `X`, chế độ ngắn 4.5s hoặc liên tục)
- [x] Xây dựng `SystemSoundPlayer` & `SynthesizedSoundGenerator` (8 âm thanh cảnh báo tổng hợp theo ngữ cảnh + 14 âm thanh hệ thống macOS, hỗ trợ nghe thử `🔊` và lặp chu kỳ khi `Persistent = true`)
- [x] Hoàn thiện `AlertsSettingsView` (CRUD nhiều mức Low/Charged, Power Source Alerts, màu preset + `ColorPicker`, Preview & `▶ Test`, `Reset Defaults`)
- [x] Viết & pass `AlertEngineTests` (6/6 tests)

### Phase 3: Thiết bị Bluetooth (`Devices`) — *Kế tiếp*
- [ ] Xây dựng `BluetoothBatteryService` (quét `IORegistry` Apple/HID peripherals + `CoreBluetooth` BLE Battery Service `0x180F`)
- [ ] Tạo model `BluetoothDeviceBattery` (pin %, trạng thái ẩn, ghim Menu Bar, ngưỡng cảnh báo riêng)
- [ ] Cập nhật `MenuBarController` & `MenuBarPopoverView` hiển thị thiết bị Bluetooth đã kết nối / đã ghim
- [ ] Hoàn thiện `DevicesSettingsView` thay cho placeholder tab `Devices`

---

## 3. Danh sách File Trọng tâm Hiện tại

- **Models:** `BatteryInfo.swift`, `AppSettings.swift`, `AlertRule.swift`
- **Services:** `IOKitBatteryService.swift`, `AlertEngine.swift`, `OverlayWindowManager.swift`, `SoundPlayer.swift`
- **App:** `PowermanApp.swift`, `AppDelegate.swift`, `AppState.swift`
- **UI:** `MenuBarController.swift`, `MenuBarIconView.swift`, `MenuBarPopoverView.swift`, `FloatingAlertBubbleView.swift`, `ScreenBorderGlowView.swift`, `SettingsRootView.swift`, `MenuBarSettingsView.swift`, `BatteryOverviewView.swift`, `AlertsSettingsView.swift`
- **Tests:** `BatteryInfoTests.swift`, `AlertEngineTests.swift`

---

## 4. Bước tiếp theo cần làm ngay (Next Immediate Steps)

1. Bắt đầu **Phase 3**: xây dựng `Models/BluetoothDeviceBattery.swift` và `Services/Bluetooth/BluetoothBatteryService.swift`.
2. Tích hợp danh sách thiết bị Bluetooth vào `MenuBarPopoverView` (`Connected Devices`) và ghim % thiết bị lên `MenuBarController`.
3. Hoàn thiện `UI/Settings/DevicesSettingsView.swift` (ẩn thiết bị, ghim lên Menu Bar, cảnh báo pin yếu cho từng thiết bị).

---

## 5. Ghi chú Kỹ thuật & Known Issues

- **Xcode Build trên môi trường bị sandbox:** Cần chạy `xcodebuild` ngoài sandbox nếu `swift-plugin-server` bị chặn.
- **Nhiệt độ & dung lượng Apple Silicon:** Đọc từ `AppleSmartBattery.BatteryData` và `AppleSmartBatteryPack.BatteryData` (centi-Celsius).
