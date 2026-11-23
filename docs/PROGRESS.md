# Theo dõi Tiến độ & Bàn giao Dự án (PROGRESS)

> **Dành cho nhân sự hoặc AI model mới tiếp nhận:** Đọc file này đầu tiên để biết dự án đang ở đâu, các tính năng nào đã chạy ổn định và bước tiếp theo cần làm ngay.

- **Cập nhật lần cuối:** 2026-11-23
- **Giai đoạn hiện tại (Current Phase):** Đã phát hành **v1.0.2 (build 5)** — Đang phát triển `[Unreleased]`: Keep Awake (Caffeinate) trên Menu Bar & tối ưu bản địa hóa theo ngữ cảnh
- **Nhánh chính:** `main` (v1.0.2 + `[Unreleased]`)
- **Trạng thái Build / Test:** `Release BUILD SUCCEEDED` (0 Swift compiler warnings), `TEST SUCCEEDED` (35/35 test cases: `BatteryInfoTests` 7/7, `AlertEngineTests` 7/7, `BluetoothBatteryTests` 3/3, `BatteryHistoryTests` 4/4, `ChargeLimitTests` 5/5, `GeneralSettingsTests` 4/4, `KeepAwakeTests` 5/5).

---

## 1. Tổng quan Lộ trình & Trạng thái

| Phase | Tên giai đoạn | Trạng thái | Ghi chú |
| :--- | :--- | :--- | :--- |
| **Phase 0** | Khởi tạo Repo, GitHub & Tài liệu chuẩn | ✅ Hoàn thành | Git, GitHub (`khuglog/powerman`), CI, Docs bàn giao |
| **Phase 1** | Core Battery (`IOKit`) + Menu Bar & Popover | ✅ Hoàn thành | Đọc pin thật Apple Silicon, Menu Bar 3 style + 4 color modes |
| **Phase 2** | Hệ thống Cảnh báo đa mức (`Alerts` + Glow + Popup) | ✅ Hoàn thành | Low/Charged/Power rules, Overlay đa màn hình, 8 âm tổng hợp + 14 âm macOS |
| **Phase 3** | Thiết bị Bluetooth (`Devices`) & Ghim Menu Bar | ✅ Hoàn thành | `SPBluetoothDataType` + `IORegistry` + `IOPS` + `CoreBluetooth`, Pin Menu Bar |
| **Phase 4** | Sức khỏe pin & Biểu đồ lịch sử (`Battery` + Charts) | ✅ Hoàn thành | Lưu lịch sử 14 ngày, Swift Charts `6h`–`14d`, Daily Usage, Top Energy Apps |
| **Phase 5** | Giới hạn sạc 80–100% (`Charge Limit`) | ✅ Hoàn thành | Native macOS `PowerUI.framework` (`PowerUISmartChargeClient`), 80–100% step 5 |
| **Phase 6** | General Settings, Tiện ích hệ thống & v1.0.0 | ✅ Hoàn thành | Launch at Login, Appearance, Language, Low Power Mode, AX Notification Dismisser |

---

## 2. Checklist Chi tiết

### Phase 0–5 (Đã hoàn thành)
- [x] Repo GitHub (`khuglog/powerman`), CI workflow, tài liệu bàn giao chuẩn
- [x] Core Battery (`IOKit`), Menu Bar 3 styles + 4 color modes, Popover dropdown
- [x] Multi-level Alerts (`Low` / `Charged` / `Power Source`), Border Glow, Floating Popup, 22 âm thanh
- [x] Bluetooth Peripheral Battery (`Devices`), Pin lên Menu Bar, Cảnh báo thiết bị riêng
- [x] Lịch sử pin 14 ngày (`JSONBatteryHistoryStore`), Swift Charts (`6h`–`14d`), `Daily Usage`, Top Energy Apps
- [x] Native Charge Limit 80–100% (`PowerUISmartChargeClient`) đồng bộ `System Settings → Battery`

### Phase 6: General Settings & Hoàn thiện v1.0.0
- [x] Xây dựng `MacSystemIntegrationService` (`Powerman/Services/System/SystemIntegrationService.swift`):
  - [x] Launch at Login qua `SMAppService.mainApp`
  - [x] App Appearance (`Auto` / `Light` / `Dark` qua `NSApp.appearance`)
  - [x] Low Power Mode observer (`NSProcessInfoPowerStateDidChange`) + bật/tắt bất đồng bộ & khôi phục độ sáng màn hình (`DisplayServices`)
  - [x] Tự động đóng thông báo pin yếu mặc định của macOS qua Accessibility (`AXUIElement`) khi được cấp quyền
- [x] Bổ sung `AlertBubbleSize` & `ScreenEdgeGlowIntensity` áp dụng trực tiếp cho `FloatingAlertBubbleView`, `ScreenBorderGlowView` và `OverlayWindowManager`
- [x] Hoàn thiện `GeneralSettingsView` (Language, Appearance, Launch at Login, Dismiss macOS Notifications, Restore Brightness, Notification Appearance + Live Preview)
- [x] Bổ sung công tắc `Low Power Mode` trong `MenuBarPopoverView` & nâng `MARKETING_VERSION` lên `1.0.0`
- [x] Viết & pass `GeneralSettingsTests` (3/3 tests)

---

## 3. Danh sách File Trọng tâm Hiện tại

- **Models:** `BatteryInfo.swift`, `AppSettings.swift`, `AlertRule.swift`, `BluetoothDeviceBattery.swift`, `BatteryHistory.swift`, `ChargeLimitState.swift`
- **Services:** `IOKitBatteryService.swift`, `BatteryHistoryStore.swift`, `EnergyConsumerService.swift`, `AlertEngine.swift`, `OverlayWindowManager.swift`, `SoundPlayer.swift`, `BluetoothBatteryService.swift`, `ChargeLimitService.swift`, `SystemIntegrationService.swift`, `SleepPreventionService.swift`
- **App:** `PowermanApp.swift`, `AppDelegate.swift`, `AppState.swift`
- **UI:** `MenuBarController.swift`, `MenuBarIconView.swift`, `MenuBarPopoverView.swift`, `FloatingAlertBubbleView.swift`, `ScreenBorderGlowView.swift`, `SettingsRootView.swift`, `MenuBarSettingsView.swift`, `BatteryOverviewView.swift`, `AlertsSettingsView.swift`, `DevicesSettingsView.swift`, `ChargingSettingsView.swift`, `GeneralSettingsView.swift`
- **Tests:** `BatteryInfoTests.swift`, `AlertEngineTests.swift`, `BluetoothBatteryTests.swift`, `BatteryHistoryTests.swift`, `ChargeLimitTests.swift`, `GeneralSettingsTests.swift`, `KeepAwakeTests.swift`

---

## 4. Hướng mở rộng tiếp theo (Backlog sau v1.0.1)

1. Hỗ trợ đọc pin iPhone / Apple Watch qua kết nối Wi-Fi/USB (`lockdownd` / Companion).
2. Đóng gói bản Release `.app` / `.dmg` có Developer ID Code Signing & Notarization hoặc Sparkle auto-updater (`Check for Updates...`).

---

## 5. Ghi chú Kỹ thuật & Known Issues

- **Low Power Mode:** Bật/tắt `pmset -a lowpowermode` trên macOS yêu cầu xác thực quản trị (`osascript ... with administrator privileges`); Powerman chạy tác vụ này bất đồng bộ để không bao giờ treo UI.
- **Xcode Build trên môi trường bị sandbox:** Cần chạy `xcodebuild` ngoài sandbox nếu `swift-plugin-server` bị chặn.
