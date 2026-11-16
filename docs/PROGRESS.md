# Theo dõi Tiến độ & Bàn giao Dự án (PROGRESS)

> **Dành cho nhân sự hoặc AI model mới tiếp nhận:** Đọc file này đầu tiên để biết dự án đang ở đâu, các tính năng nào đã chạy ổn định và bước tiếp theo cần làm ngay.

- **Cập nhật lần cuối:** 2026-11-16
- **Giai đoạn hiện tại (Current Phase):** Hoàn thành **Phase 5 (Giới hạn sạc 80–100% — `Charge Limit`)** — Sẵn sàng chuyển sang **Phase 6 (Final Polish)**
- **Nhánh chính:** `main`
- **Trạng thái Build / Test:** `TEST SUCCEEDED` (20/20 test cases: `BatteryInfoTests` 5/5, `AlertEngineTests` 6/6, `BluetoothBatteryTests` 3/3, `BatteryHistoryTests` 4/4, `ChargeLimitTests` 2/2, `SWIFT_STRICT_CONCURRENCY = complete`)

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
| **Phase 6** | General Settings, Tiện ích hệ thống & Đóng gói | ⏳ Chưa bắt đầu | Launch at Login, Appearance, Language, Low Power Mode, Dismiss macOS notif |

---

## 2. Checklist Chi tiết

### Phase 0–4 (Đã hoàn thành)
- [x] Repo GitHub (`khuglog/powerman`), CI workflow, tài liệu bàn giao chuẩn
- [x] Core Battery (`IOKit`), Menu Bar 3 styles + 4 color modes, Popover dropdown
- [x] Multi-level Alerts (`Low` / `Charged` / `Power Source`), Border Glow, Floating Popup, 22 âm thanh
- [x] Bluetooth Peripheral Battery (`Devices`), Pin lên Menu Bar, Cảnh báo thiết bị riêng
- [x] Lịch sử pin 14 ngày (`JSONBatteryHistoryStore`), Swift Charts (`6h`–`14d`), `Daily Usage`, Top Energy Apps

### Phase 5: Giới hạn sạc 80–100% (`Charge Limit`)
- [x] Khảo sát thực nghiệm: macOS 27 (`Mac15,6`) hỗ trợ trực tiếp `PowerUISmartChargeClient` trong `PowerUI.framework` (`availableChargeLimits: [80, 85, 90, 95, 100]`, đọc & ghi không cần root)
- [x] Xây dựng `ChargeLimitState` & `NativeChargeLimitService` (`Powerman/Services/Charging/ChargeLimitService.swift`)
- [x] Tích hợp vào `AppState` & hiển thị trạng thái `Paused at X% Limit` trong `MenuBarPopoverView`
- [x] Hoàn thiện `ChargingSettingsView` (toggle, slider 80–100% bước 5%, banner xác nhận & liên kết `System Settings → Battery`)
- [x] Viết & pass `ChargeLimitTests` (2/2 tests)

### Phase 6: General Settings & Hoàn thiện UX — *Kế tiếp*
- [ ] Xây dựng `LaunchAtLoginService` (`SMAppService.mainApp`)
- [ ] Hoàn thiện `GeneralSettingsView`: App Appearance (Auto/Light/Dark), Launch at Login, Low Power Mode + Restore Brightness, Dismiss macOS Battery Notifications (Accessibility `AXUIElement` tùy chọn), Notification Appearance preview
- [ ] Tích hợp công tắc `Low Power Mode` trong `MenuBarPopoverView`
- [ ] Kiểm thử toàn diện & cập nhật tài liệu bàn giao v1.0

---

## 3. Danh sách File Trọng tâm Hiện tại

- **Models:** `BatteryInfo.swift`, `AppSettings.swift`, `AlertRule.swift`, `BluetoothDeviceBattery.swift`, `BatteryHistory.swift`, `ChargeLimitState.swift`
- **Services:** `IOKitBatteryService.swift`, `BatteryHistoryStore.swift`, `EnergyConsumerService.swift`, `AlertEngine.swift`, `OverlayWindowManager.swift`, `SoundPlayer.swift`, `BluetoothBatteryService.swift`, `ChargeLimitService.swift`
- **App:** `PowermanApp.swift`, `AppDelegate.swift`, `AppState.swift`
- **UI:** `MenuBarController.swift`, `MenuBarIconView.swift`, `MenuBarPopoverView.swift`, `FloatingAlertBubbleView.swift`, `ScreenBorderGlowView.swift`, `SettingsRootView.swift`, `MenuBarSettingsView.swift`, `BatteryOverviewView.swift`, `AlertsSettingsView.swift`, `DevicesSettingsView.swift`, `ChargingSettingsView.swift`
- **Tests:** `BatteryInfoTests.swift`, `AlertEngineTests.swift`, `BluetoothBatteryTests.swift`, `BatteryHistoryTests.swift`, `ChargeLimitTests.swift`

---

## 4. Bước tiếp theo cần làm ngay (Next Immediate Steps)

1. Bắt đầu **Phase 6**: xây dựng `Services/System/SystemIntegrationService.swift` (Launch at Login via `SMAppService.mainApp`, App Appearance override, Brightness & Low Power Mode, Accessibility Notification Dismisser).
2. Hoàn thiện `UI/Settings/GeneralSettingsView.swift` và công tắc `Low Power Mode` trong `MenuBarPopoverView`.

---

## 5. Ghi chú Kỹ thuật & Known Issues

- **Native Charge Limit (`PowerUI.framework`):** Trên macOS 27 (`Mac15,6`), `PowerUISmartChargeClient` hoạt động trực tiếp ở user space (không cần root daemon) cho các mức `[80, 85, 90, 95, 100]` và đồng bộ hai chiều với `System Settings → Battery`. Nếu chạy trên máy không hỗ trợ MCL (`isMCLSupported == false`), UI tự hiển thị thông báo rõ ràng.
